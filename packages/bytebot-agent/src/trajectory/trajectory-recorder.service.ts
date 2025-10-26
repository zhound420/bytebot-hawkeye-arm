import { Injectable, Logger, Inject, forwardRef } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import {
  TrajectoryRecordingConfig,
  IterationSnapshot,
  TrajectoryData,
  TrajectoryMetrics,
} from './types/trajectory.types';
import { TrajectorySearchService } from './trajectory-search.service';

/**
 * Records task execution trajectories for learning and analysis
 *
 * Captures:
 * - Each iteration's system prompt, messages, tool calls, results
 * - Token usage and timing metrics
 * - Success/failure outcomes
 * - Quality metrics (click accuracy, error rate, etc.)
 */
@Injectable()
export class TrajectoryRecorderService {
  private readonly logger = new Logger(TrajectoryRecorderService.name);
  private readonly config: TrajectoryRecordingConfig;

  // In-memory trajectory tracking (per task)
  private activeTrajectories = new Map<string, TrajectoryData>();

  // Pause state (can be toggled at runtime)
  private paused = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
    @Inject(forwardRef(() => TrajectorySearchService))
    private readonly trajectorySearch: TrajectorySearchService,
  ) {
    this.config = {
      enabled: this.configService.get<boolean>(
        'BYTEBOT_RECORD_TRAJECTORIES',
        false,
      ),
      modelProviders: this.configService
        .get<string>('BYTEBOT_RECORD_MODEL_PROVIDERS', '')
        .split(',')
        .filter((p) => p.length > 0),
      minDuration: this.configService.get<number>(
        'BYTEBOT_RECORD_MIN_DURATION',
        5,
      ),
      recordFailures: this.configService.get<boolean>(
        'BYTEBOT_RECORD_FAILURES',
        true,
      ),
    };

    if (this.config.enabled) {
      this.logger.log(
        `Trajectory recording enabled for providers: ${this.config.modelProviders.length > 0 ? this.config.modelProviders.join(', ') : 'ALL'}`,
      );
    }
  }

  /**
   * Check if trajectory recording is enabled
   */
  isEnabled(): boolean {
    return this.config.enabled;
  }

  /**
   * Check if we should record for this model provider
   */
  shouldRecord(modelProvider: string): boolean {
    if (!this.config.enabled) return false;
    if (this.paused) return false;

    // If no specific providers configured, record all
    if (this.config.modelProviders.length === 0) return true;

    // Otherwise check if this provider is in the list
    return this.config.modelProviders.includes(modelProvider);
  }

  /**
   * Start recording a new trajectory
   */
  async startTrajectory(
    taskId: string,
    modelProvider: string,
    modelName: string,
  ): Promise<void> {
    if (!this.shouldRecord(modelProvider)) {
      return;
    }

    this.logger.debug(`Starting trajectory recording for task ${taskId}`);

    const trajectoryData: TrajectoryData = {
      taskId,
      modelProvider,
      modelName,
      success: false,
      startedAt: new Date(),
      iterations: [],
      metrics: {
        iterationCount: 0,
        toolCallsCount: 0,
        tokenUsage: { input: 0, output: 0, total: 0 },
        errorRate: 0,
        userInterventions: 0,
      },
    };

    this.activeTrajectories.set(taskId, trajectoryData);
  }

  /**
   * Record a single iteration
   */
  async recordIteration(
    taskId: string,
    snapshot: IterationSnapshot,
  ): Promise<void> {
    const trajectory = this.activeTrajectories.get(taskId);
    if (!trajectory) {
      return;
    }

    // Add iteration to trajectory
    trajectory.iterations.push(snapshot);

    // Update metrics
    trajectory.metrics.iterationCount++;
    trajectory.metrics.tokenUsage.input += snapshot.tokenUsage.input;
    trajectory.metrics.tokenUsage.output += snapshot.tokenUsage.output;
    trajectory.metrics.tokenUsage.total +=
      snapshot.tokenUsage.input + snapshot.tokenUsage.output;

    if (snapshot.toolCalls) {
      trajectory.metrics.toolCallsCount += snapshot.toolCalls.length;
    }

    this.logger.debug(
      `Recorded iteration ${snapshot.iterationNumber} for task ${taskId}`,
    );
  }

  /**
   * Record that user took control (intervention)
   */
  async recordUserIntervention(taskId: string): Promise<void> {
    const trajectory = this.activeTrajectories.get(taskId);
    if (!trajectory) {
      return;
    }

    trajectory.metrics.userInterventions++;
    this.logger.debug(`Recorded user intervention for task ${taskId}`);
  }

  /**
   * Complete trajectory recording and save to database
   */
  async completeTrajectory(
    taskId: string,
    success: boolean,
    additionalMetrics?: Partial<TrajectoryMetrics>,
  ): Promise<void> {
    const trajectory = this.activeTrajectories.get(taskId);
    if (!trajectory) {
      return;
    }

    // Check minimum duration
    const duration =
      (new Date().getTime() - trajectory.startedAt.getTime()) / 1000;
    if (duration < this.config.minDuration) {
      this.logger.debug(
        `Trajectory for task ${taskId} too short (${duration}s), skipping save`,
      );
      this.activeTrajectories.delete(taskId);
      return;
    }

    // Update trajectory data
    trajectory.success = success;
    trajectory.completedAt = new Date();

    // Merge additional metrics
    if (additionalMetrics) {
      trajectory.metrics = { ...trajectory.metrics, ...additionalMetrics };
    }

    // Calculate quality score
    const qualityScore = this.calculateQualityScore(trajectory);

    // Skip recording failures if configured
    if (!success && !this.config.recordFailures) {
      this.logger.debug(`Skipping failed trajectory for task ${taskId}`);
      this.activeTrajectories.delete(taskId);
      return;
    }

    try {
      // Save to database
      await this.saveTrajectory(trajectory, qualityScore);
      this.logger.log(
        `Saved trajectory for task ${taskId} (success: ${success}, quality: ${qualityScore?.toFixed(2)})`,
      );
    } catch (error) {
      this.logger.error(
        `Failed to save trajectory for task ${taskId}: ${error.message}`,
      );
    } finally {
      this.activeTrajectories.delete(taskId);
    }
  }

  /**
   * Save trajectory and steps to database
   */
  private async saveTrajectory(
    trajectory: TrajectoryData,
    qualityScore: number | null,
  ): Promise<void> {
    const savedTrajectory = await this.prisma.taskTrajectory.create({
      data: {
        taskId: trajectory.taskId,
        modelProvider: trajectory.modelProvider,
        modelName: trajectory.modelName,
        success: trajectory.success,
        qualityScore,
        iterationCount: trajectory.metrics.iterationCount,
        toolCallsCount: trajectory.metrics.toolCallsCount,
        tokenUsageInput: trajectory.metrics.tokenUsage.input,
        tokenUsageOutput: trajectory.metrics.tokenUsage.output,
        tokenUsageTotal: trajectory.metrics.tokenUsage.total,
        errorRate: trajectory.metrics.errorRate,
        clickAccuracy: trajectory.metrics.clickAccuracy,
        userInterventions: trajectory.metrics.userInterventions,
        startedAt: trajectory.startedAt,
        completedAt: trajectory.completedAt,
        steps: {
          create: trajectory.iterations.map((iteration) => ({
            iterationNumber: iteration.iterationNumber,
            systemPrompt: iteration.systemPrompt,
            messagesSnapshot: iteration.messages,
            toolCalls: iteration.toolCalls || null,
            toolResults: iteration.toolResults || null,
            reasoning: iteration.reasoning || null,
            tokenUsageInput: iteration.tokenUsage.input,
            tokenUsageOutput: iteration.tokenUsage.output,
            timestamp: iteration.timestamp,
          })),
        },
      },
      include: {
        task: {
          select: {
            description: true,
          },
        },
      },
    });

    // Generate and store embedding for semantic search
    if (savedTrajectory.task?.description) {
      await this.trajectorySearch.storeEmbedding(
        savedTrajectory.id,
        savedTrajectory.task.description,
      );
    }
  }

  /**
   * Calculate quality score based on execution metrics
   * Returns value between 0.0 and 1.0
   */
  private calculateQualityScore(trajectory: TrajectoryData): number | null {
    if (!trajectory.success) {
      return null; // Failed tasks don't get quality scores
    }

    const metrics = trajectory.metrics;
    let score = 1.0;

    // Penalty for user interventions (heavy penalty)
    if (metrics.userInterventions > 0) {
      score -= 0.3 * Math.min(metrics.userInterventions, 3);
    }

    // Penalty for high error rate
    if (metrics.errorRate > 0.1) {
      score -= 0.2 * (metrics.errorRate - 0.1);
    }

    // Penalty for low click accuracy
    if (metrics.clickAccuracy !== undefined && metrics.clickAccuracy < 0.8) {
      score -= 0.2 * (0.8 - metrics.clickAccuracy);
    }

    // Penalty for inefficient execution (too many iterations)
    const iterationPenalty = Math.max(0, (metrics.iterationCount - 10) * 0.02);
    score -= iterationPenalty;

    // Clamp to [0.0, 1.0]
    return Math.max(0.0, Math.min(1.0, score));
  }

  /**
   * Get active trajectory count (for monitoring)
   */
  getActiveCount(): number {
    return this.activeTrajectories.size;
  }

  /**
   * Cancel trajectory recording (e.g., if task is cancelled)
   */
  async cancelTrajectory(taskId: string): Promise<void> {
    this.activeTrajectories.delete(taskId);
    this.logger.debug(`Cancelled trajectory recording for task ${taskId}`);
  }

  /**
   * Get statistics about recorded trajectories
   */
  async getStatistics(): Promise<{
    total: number;
    byProvider: Record<string, number>;
    successRate: number;
    averageQuality: number;
  }> {
    const [total, byProvider, successCount, qualityStats] = await Promise.all([
      this.prisma.taskTrajectory.count(),
      this.prisma.taskTrajectory.groupBy({
        by: ['modelProvider'],
        _count: true,
      }),
      this.prisma.taskTrajectory.count({
        where: { success: true },
      }),
      this.prisma.taskTrajectory.aggregate({
        _avg: { qualityScore: true },
        where: { qualityScore: { not: null } },
      }),
    ]);

    return {
      total,
      byProvider: Object.fromEntries(
        byProvider.map((p) => [p.modelProvider, p._count]),
      ),
      successRate: total > 0 ? successCount / total : 0,
      averageQuality: qualityStats._avg.qualityScore || 0,
    };
  }

  /**
   * Pause trajectory recording (can be resumed later)
   */
  pause(): void {
    this.paused = true;
    this.logger.log('Trajectory recording paused');
  }

  /**
   * Resume trajectory recording
   */
  resume(): void {
    this.paused = false;
    this.logger.log('Trajectory recording resumed');
  }

  /**
   * Check if recording is currently paused
   */
  isPaused(): boolean {
    return this.paused;
  }
}
