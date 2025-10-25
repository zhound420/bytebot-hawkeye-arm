import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  TrajectoryExport,
  ExportedTrajectory,
  TrajectoryWithRelations,
} from './types/trajectory.types';
import * as fs from 'fs/promises';
import * as path from 'path';

/**
 * Exports trajectories in various formats for fine-tuning
 *
 * Supported formats:
 * - OpenAI (JSONL with messages)
 * - Gemini (format TBD)
 * - Anthropic (format TBD)
 */
@Injectable()
export class TrajectoryExportService {
  private readonly logger = new Logger(TrajectoryExportService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Export trajectories for fine-tuning
   */
  async exportForFineTuning(options: {
    format: 'openai' | 'gemini' | 'anthropic';
    modelProvider?: string;
    minQuality?: number;
    successOnly?: boolean;
    limit?: number;
    outputPath?: string;
  }): Promise<TrajectoryExport> {
    const {
      format,
      modelProvider,
      minQuality = 0.7,
      successOnly = true,
      limit,
    } = options;

    this.logger.log(
      `Exporting trajectories in ${format} format (minQuality: ${minQuality})`,
    );

    // Fetch trajectories matching criteria
    const trajectories = await this.prisma.taskTrajectory.findMany({
      where: {
        success: successOnly ? true : undefined,
        qualityScore: minQuality ? { gte: minQuality } : undefined,
        modelProvider: modelProvider || undefined,
      },
      include: {
        steps: {
          orderBy: { iterationNumber: 'asc' },
        },
        task: {
          select: {
            description: true,
            status: true,
          },
        },
      },
      orderBy: { qualityScore: 'desc' },
      take: limit,
    });

    this.logger.log(`Found ${trajectories.length} trajectories to export`);

    // Convert to format-specific structure
    const exportedTrajectories: ExportedTrajectory[] = [];

    for (const trajectory of trajectories) {
      let messages: any[];

      switch (format) {
        case 'openai':
          messages = this.convertToOpenAIFormat(
            trajectory as TrajectoryWithRelations,
          );
          break;
        case 'gemini':
          messages = this.convertToGeminiFormat(
            trajectory as TrajectoryWithRelations,
          );
          break;
        case 'anthropic':
          messages = this.convertToAnthropicFormat(
            trajectory as TrajectoryWithRelations,
          );
          break;
        default:
          throw new Error(`Unsupported export format: ${format}`);
      }

      exportedTrajectories.push({
        messages,
        metadata: {
          taskId: trajectory.taskId,
          modelProvider: trajectory.modelProvider,
          success: trajectory.success,
          qualityScore: trajectory.qualityScore,
        },
      });
    }

    // Calculate statistics
    const successCount = trajectories.filter((t) => t.success).length;
    const qualityScores = trajectories
      .map((t) => t.qualityScore)
      .filter((q): q is number => q !== null);
    const averageQuality =
      qualityScores.length > 0
        ? qualityScores.reduce((a, b) => a + b, 0) / qualityScores.length
        : 0;

    const exportData: TrajectoryExport = {
      format,
      trajectories: exportedTrajectories,
      metadata: {
        exportDate: new Date(),
        totalTrajectories: trajectories.length,
        successRate: trajectories.length > 0 ? successCount / trajectories.length : 0,
        averageQuality,
      },
    };

    // Write to file if output path specified
    if (options.outputPath) {
      await this.writeExportFile(exportData, options.outputPath);
    }

    return exportData;
  }

  /**
   * Convert trajectory to OpenAI fine-tuning format
   * Format: JSONL with {messages: [...]}
   * https://platform.openai.com/docs/guides/fine-tuning
   */
  private convertToOpenAIFormat(
    trajectory: TrajectoryWithRelations,
  ): any[] {
    const messages: any[] = [];

    // Add system message (from first step)
    if (trajectory.steps.length > 0) {
      messages.push({
        role: 'system',
        content: trajectory.steps[0].systemPrompt,
      });
    }

    // Add user message (initial task)
    messages.push({
      role: 'user',
      content: trajectory.task.description,
    });

    // Add conversation steps
    for (const step of trajectory.steps) {
      // Add assistant response (convert from Anthropic format to OpenAI)
      if (step.messagesSnapshot && Array.isArray(step.messagesSnapshot)) {
        for (const msg of step.messagesSnapshot as any[]) {
          if (msg.role === 'assistant') {
            // Convert content blocks to OpenAI format
            const content = this.convertContentToOpenAI(msg.content);
            messages.push({
              role: 'assistant',
              content,
            });
          } else if (msg.role === 'user') {
            // Tool results as user messages
            const content = this.convertContentToOpenAI(msg.content);
            messages.push({
              role: 'user',
              content,
            });
          }
        }
      }
    }

    return messages;
  }

  /**
   * Convert content blocks to OpenAI format
   */
  private convertContentToOpenAI(content: any): string {
    if (typeof content === 'string') {
      return content;
    }

    if (Array.isArray(content)) {
      // Extract text from content blocks
      return content
        .filter((block: any) => block.type === 'text')
        .map((block: any) => block.text)
        .join('\n');
    }

    return JSON.stringify(content);
  }

  /**
   * Convert trajectory to Gemini fine-tuning format
   * TODO: Implement Gemini-specific format
   */
  private convertToGeminiFormat(
    trajectory: TrajectoryWithRelations,
  ): any[] {
    // Placeholder - Gemini format may be similar to OpenAI
    return this.convertToOpenAIFormat(trajectory);
  }

  /**
   * Convert trajectory to Anthropic fine-tuning format
   * Keep native Anthropic format
   */
  private convertToAnthropicFormat(
    trajectory: TrajectoryWithRelations,
  ): any[] {
    const messages: any[] = [];

    // Anthropic format keeps content blocks structure
    for (const step of trajectory.steps) {
      if (step.messagesSnapshot && Array.isArray(step.messagesSnapshot)) {
        messages.push(...step.messagesSnapshot);
      }
    }

    return messages;
  }

  /**
   * Write export data to file
   */
  private async writeExportFile(
    exportData: TrajectoryExport,
    outputPath: string,
  ): Promise<void> {
    // Ensure directory exists
    const dir = path.dirname(outputPath);
    await fs.mkdir(dir, { recursive: true });

    if (exportData.format === 'openai') {
      // OpenAI format: JSONL (one JSON object per line)
      const lines = exportData.trajectories.map((t) =>
        JSON.stringify({ messages: t.messages }),
      );
      await fs.writeFile(outputPath, lines.join('\n'));
      this.logger.log(`Wrote ${lines.length} examples to ${outputPath}`);
    } else {
      // Other formats: regular JSON
      await fs.writeFile(outputPath, JSON.stringify(exportData, null, 2));
      this.logger.log(`Wrote export data to ${outputPath}`);
    }
  }

  /**
   * Export statistics about trajectories
   */
  async exportStatistics(outputPath?: string): Promise<any> {
    const [
      totalCount,
      successCount,
      byProvider,
      avgMetrics,
      qualityDistribution,
    ] = await Promise.all([
      // Total count
      this.prisma.taskTrajectory.count(),

      // Success count
      this.prisma.taskTrajectory.count({ where: { success: true } }),

      // By provider
      this.prisma.taskTrajectory.groupBy({
        by: ['modelProvider'],
        _count: true,
        _avg: { qualityScore: true },
      }),

      // Average metrics
      this.prisma.taskTrajectory.aggregate({
        _avg: {
          iterationCount: true,
          toolCallsCount: true,
          tokenUsageTotal: true,
          errorRate: true,
          clickAccuracy: true,
        },
      }),

      // Quality score distribution
      this.prisma.$queryRaw`
        SELECT
          CASE
            WHEN "qualityScore" >= 0.9 THEN 'excellent'
            WHEN "qualityScore" >= 0.7 THEN 'good'
            WHEN "qualityScore" >= 0.5 THEN 'fair'
            ELSE 'poor'
          END as quality_tier,
          COUNT(*) as count
        FROM "TaskTrajectory"
        WHERE "qualityScore" IS NOT NULL
        GROUP BY quality_tier
        ORDER BY quality_tier DESC
      `,
    ]);

    const stats = {
      summary: {
        total: totalCount,
        successful: successCount,
        successRate:
          totalCount > 0 ? ((successCount / totalCount) * 100).toFixed(1) : '0.0',
      },
      byProvider: byProvider.map((p) => ({
        provider: p.modelProvider,
        count: p._count,
        avgQuality: p._avg.qualityScore?.toFixed(2) || 'N/A',
      })),
      averageMetrics: {
        iterations: avgMetrics._avg.iterationCount?.toFixed(1) || 'N/A',
        toolCalls: avgMetrics._avg.toolCallsCount?.toFixed(1) || 'N/A',
        tokens: avgMetrics._avg.tokenUsageTotal?.toFixed(0) || 'N/A',
        errorRate:
          avgMetrics._avg.errorRate !== null
            ? `${(avgMetrics._avg.errorRate * 100).toFixed(1)}%`
            : 'N/A',
        clickAccuracy:
          avgMetrics._avg.clickAccuracy !== null
            ? `${(avgMetrics._avg.clickAccuracy * 100).toFixed(1)}%`
            : 'N/A',
      },
      qualityDistribution,
    };

    if (outputPath) {
      await fs.writeFile(outputPath, JSON.stringify(stats, null, 2));
      this.logger.log(`Wrote statistics to ${outputPath}`);
    }

    return stats;
  }

  /**
   * Clean up old low-quality trajectories
   */
  async cleanup(options: {
    olderThanDays?: number;
    maxQuality?: number;
    keepCount?: number;
  }): Promise<number> {
    const { olderThanDays = 90, maxQuality = 0.3, keepCount = 100 } = options;

    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - olderThanDays);

    // Keep high-quality trajectories and recent ones
    const deleteResult = await this.prisma.taskTrajectory.deleteMany({
      where: {
        AND: [
          { createdAt: { lt: cutoffDate } },
          {
            OR: [
              { qualityScore: { lte: maxQuality } },
              { qualityScore: null },
            ],
          },
        ],
      },
    });

    this.logger.log(
      `Cleaned up ${deleteResult.count} old low-quality trajectories`,
    );

    return deleteResult.count;
  }
}
