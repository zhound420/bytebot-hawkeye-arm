import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import OpenAI from 'openai';
import {
  TrajectorySearchParams,
  SimilarTrajectory,
  CondensedExample,
  FewShotConfig,
} from './types/trajectory.types';

/**
 * Searches for similar trajectories using semantic similarity
 *
 * Uses:
 * - OpenAI embeddings API to generate vectors
 * - pgvector for fast similarity search
 * - Condensed examples for few-shot prompting
 */
@Injectable()
export class TrajectorySearchService {
  private readonly logger = new Logger(TrajectorySearchService.name);
  private readonly config: FewShotConfig;
  private readonly openai: OpenAI | null = null;
  private readonly embeddingModel = 'text-embedding-3-small'; // 1536 dimensions, cheap
  private readonly embeddingCache = new Map<string, number[]>(); // Simple cache

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
  ) {
    this.config = {
      enabled: this.configService.get<boolean>('BYTEBOT_USE_FEW_SHOT', false),
      count: this.configService.get<number>('BYTEBOT_FEW_SHOT_COUNT', 3),
      similarityThreshold: this.configService.get<number>(
        'BYTEBOT_FEW_SHOT_SIMILARITY',
        0.7,
      ),
      sourceProviders: this.configService
        .get<string>('BYTEBOT_FEW_SHOT_SOURCE_PROVIDERS', 'anthropic')
        .split(',')
        .filter((p) => p.length > 0),
    };

    // Initialize OpenAI client if API key is available
    const apiKey =
      this.configService.get<string>('OPENAI_API_KEY') ||
      this.configService.get<string>('BYTEBOT_EMBEDDING_API_KEY');

    if (apiKey) {
      this.openai = new OpenAI({ apiKey });
      if (this.config.enabled) {
        this.logger.log('Few-shot learning enabled');
      }
    } else if (this.config.enabled) {
      this.logger.warn(
        'Few-shot learning enabled but no OpenAI API key found for embeddings',
      );
    }
  }

  /**
   * Check if few-shot learning is enabled and available
   */
  isAvailable(): boolean {
    return this.config.enabled && this.openai !== null;
  }

  /**
   * Generate embedding for a text string
   */
  private async generateEmbedding(text: string): Promise<number[]> {
    if (!this.openai) {
      throw new Error('OpenAI client not initialized');
    }

    // Check cache first
    if (this.embeddingCache.has(text)) {
      return this.embeddingCache.get(text)!;
    }

    try {
      const response = await this.openai.embeddings.create({
        model: this.embeddingModel,
        input: text,
      });

      const embedding = response.data[0].embedding;

      // Cache the embedding (limit cache size)
      if (this.embeddingCache.size > 100) {
        const firstKey = this.embeddingCache.keys().next().value;
        this.embeddingCache.delete(firstKey);
      }
      this.embeddingCache.set(text, embedding);

      return embedding;
    } catch (error) {
      this.logger.error(`Failed to generate embedding: ${error.message}`);
      throw error;
    }
  }

  /**
   * Store embedding for a trajectory
   */
  async storeEmbedding(
    trajectoryId: string,
    taskDescription: string,
  ): Promise<void> {
    if (!this.openai) {
      return; // Skip if embeddings not available
    }

    try {
      const embedding = await this.generateEmbedding(taskDescription);

      // Store in database using raw SQL (pgvector)
      await this.prisma.$executeRaw`
        INSERT INTO "TrajectoryEmbedding" (id, "trajectoryId", "taskDescription", embedding, "createdAt", "updatedAt")
        VALUES (gen_random_uuid(), ${trajectoryId}, ${taskDescription}, ${embedding}::vector, NOW(), NOW())
        ON CONFLICT ("trajectoryId") DO UPDATE
        SET "taskDescription" = ${taskDescription},
            embedding = ${embedding}::vector,
            "updatedAt" = NOW()
      `;

      this.logger.debug(
        `Stored embedding for trajectory ${trajectoryId.slice(0, 8)}...`,
      );
    } catch (error) {
      this.logger.error(
        `Failed to store embedding for trajectory ${trajectoryId}: ${error.message}`,
      );
    }
  }

  /**
   * Search for similar successful trajectories
   */
  async findSimilar(
    params: TrajectorySearchParams,
  ): Promise<SimilarTrajectory[]> {
    if (!this.isAvailable()) {
      return [];
    }

    try {
      // Generate embedding for search query
      const queryEmbedding = await this.generateEmbedding(
        params.taskDescription,
      );

      // Build SQL query with filters
      const topK = params.topK || this.config.count;
      const minSimilarity =
        params.minSimilarity || this.config.similarityThreshold || 0.7;
      const successOnly = params.successOnly !== false; // Default to true

      // Use raw SQL for vector similarity search
      const results: any[] = await this.prisma.$queryRaw`
        SELECT
          t.id,
          t."taskId",
          t."modelProvider",
          t."modelName",
          t.success,
          t."qualityScore",
          t."iterationCount",
          t."toolCallsCount",
          t."startedAt",
          1 - (e.embedding <=> ${queryEmbedding}::vector) as similarity
        FROM "TaskTrajectory" t
        JOIN "TrajectoryEmbedding" e ON e."trajectoryId" = t.id
        WHERE t.success = ${successOnly}
          ${params.modelProvider ? this.prisma.$queryRaw`AND t."modelProvider" = ${params.modelProvider}` : this.prisma.$queryRaw``}
          ${params.minQuality ? this.prisma.$queryRaw`AND t."qualityScore" >= ${params.minQuality}` : this.prisma.$queryRaw``}
          ${this.config.sourceProviders.length > 0 ? this.prisma.$queryRaw`AND t."modelProvider" = ANY(${this.config.sourceProviders})` : this.prisma.$queryRaw``}
        ORDER BY e.embedding <=> ${queryEmbedding}::vector
        LIMIT ${topK}
      `;

      // Filter by similarity threshold and load full data
      const similarTrajectories: SimilarTrajectory[] = [];

      for (const result of results) {
        if (result.similarity < minSimilarity) {
          continue;
        }

        // Load full trajectory with steps
        const trajectory = await this.prisma.taskTrajectory.findUnique({
          where: { id: result.id },
          include: {
            steps: {
              orderBy: { iterationNumber: 'asc' },
            },
            task: {
              select: {
                description: true,
              },
            },
          },
        });

        if (!trajectory) continue;

        // Condense trajectory into example format
        const condensedExample = this.condenseTrajectory(trajectory);

        similarTrajectories.push({
          trajectory: trajectory as any,
          similarity: parseFloat(result.similarity),
          condensedExample,
        });
      }

      this.logger.debug(
        `Found ${similarTrajectories.length} similar trajectories (similarity >= ${minSimilarity})`,
      );

      return similarTrajectories;
    } catch (error) {
      this.logger.error(`Failed to search trajectories: ${error.message}`);
      return [];
    }
  }

  /**
   * Condense a trajectory into a concise few-shot example
   */
  private condenseTrajectory(trajectory: any): CondensedExample {
    const keySteps: string[] = [];
    const toolsUsed = new Set<string>();

    // Extract key information from each step
    for (const step of trajectory.steps) {
      // Extract tool calls
      if (step.toolCalls && Array.isArray(step.toolCalls)) {
        for (const toolCall of step.toolCalls) {
          if (toolCall.name) {
            toolsUsed.add(toolCall.name);
          }
        }
      }

      // Extract reasoning or key text content
      if (step.reasoning) {
        keySteps.push(step.reasoning.slice(0, 200)); // Truncate
      } else if (step.messagesSnapshot && Array.isArray(step.messagesSnapshot)) {
        // Find text content blocks
        for (const msg of step.messagesSnapshot) {
          if (msg.role === 'assistant' && Array.isArray(msg.content)) {
            for (const block of msg.content) {
              if (block.type === 'text' && block.text) {
                // Extract key phrases (simple heuristic: first sentence)
                const firstSentence = block.text.split('.')[0];
                if (firstSentence.length > 10 && firstSentence.length < 150) {
                  keySteps.push(firstSentence);
                }
              }
            }
          }
        }
      }
    }

    // Limit key steps to avoid bloat
    const limitedSteps = keySteps.slice(0, 5);

    return {
      taskDescription: trajectory.task.description,
      keySteps: limitedSteps,
      toolsUsed: Array.from(toolsUsed),
      outcome: trajectory.success ? 'Completed successfully' : 'Failed',
      reasoning:
        trajectory.steps[0]?.reasoning?.slice(0, 300) ||
        'Systematic approach with observation and verification',
    };
  }

  /**
   * Format similar trajectories as few-shot examples for prompt injection
   */
  formatAsFewShot(similarTrajectories: SimilarTrajectory[]): string {
    if (similarTrajectories.length === 0) {
      return '';
    }

    const examples = similarTrajectories
      .map((similar, index) => {
        const example = similar.condensedExample;
        const similarity = (similar.similarity * 100).toFixed(0);

        return `
**Example ${index + 1}** (${similarity}% similar):
Task: "${example.taskDescription}"
Approach:
${example.keySteps.map((step, i) => `  ${i + 1}. ${step}`).join('\n')}
Tools used: ${example.toolsUsed.join(', ')}
Outcome: ${example.outcome}
    `.trim();
      })
      .join('\n\n');

    return `
## Similar Tasks Completed Successfully

Here are ${similarTrajectories.length} similar task(s) that were completed successfully. Use these as guidance for your approach:

${examples}

---
`.trim();
  }

  /**
   * Get most used few-shot examples
   */
  async getTopExamples(limit: number = 10): Promise<any[]> {
    return this.prisma.fewShotExample.findMany({
      where: { isActive: true },
      orderBy: { usageCount: 'desc' },
      take: limit,
      include: {
        trajectory: {
          select: {
            modelProvider: true,
            modelName: true,
            qualityScore: true,
            success: true,
          },
        },
      },
    });
  }

  /**
   * Record usage of a few-shot example
   */
  async recordExampleUsage(exampleId: string): Promise<void> {
    await this.prisma.fewShotExample.update({
      where: { id: exampleId },
      data: {
        usageCount: { increment: 1 },
        lastUsedAt: new Date(),
      },
    });
  }
}
