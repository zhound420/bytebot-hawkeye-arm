/**
 * Trajectory Distillation & Few-Shot Learning Types
 *
 * Types for recording, analyzing, and replaying task execution trajectories
 * to enable learning from successful Claude runs.
 */

import { TaskTrajectory, TrajectoryStep, FewShotExample } from '@prisma/client';

/**
 * Configuration for trajectory recording
 */
export interface TrajectoryRecordingConfig {
  /** Whether to record trajectories */
  enabled: boolean;
  /** Only record these model providers (empty = all) */
  modelProviders?: string[];
  /** Minimum task duration to record (seconds) */
  minDuration?: number;
  /** Whether to record failed tasks */
  recordFailures?: boolean;
}

/**
 * Configuration for few-shot learning
 */
export interface FewShotConfig {
  /** Whether to use few-shot learning */
  enabled: boolean;
  /** Number of examples to retrieve */
  count: number;
  /** Minimum similarity threshold (0.0-1.0) */
  similarityThreshold?: number;
  /** Only retrieve examples from these providers */
  sourceProviders?: string[];
}

/**
 * Snapshot of a single iteration for trajectory recording
 */
export interface IterationSnapshot {
  iterationNumber: number;
  systemPrompt: string;
  messages: any[]; // Message content blocks
  toolCalls?: any[]; // Tool use blocks
  toolResults?: any[]; // Tool result blocks
  reasoning?: string; // For o1/o3 models
  tokenUsage: {
    input: number;
    output: number;
  };
  timestamp: Date;
}

/**
 * Complete trajectory data for a task execution
 */
export interface TrajectoryData {
  taskId: string;
  modelProvider: string;
  modelName: string;
  success: boolean;
  startedAt: Date;
  completedAt?: Date;
  iterations: IterationSnapshot[];
  metrics: TrajectoryMetrics;
}

/**
 * Metrics calculated from trajectory execution
 */
export interface TrajectoryMetrics {
  iterationCount: number;
  toolCallsCount: number;
  tokenUsage: {
    input: number;
    output: number;
    total: number;
  };
  errorRate: number; // 0.0-1.0
  clickAccuracy?: number; // 0.0-1.0
  userInterventions: number;
  qualityScore?: number; // 0.0-1.0
}

/**
 * Condensed few-shot example for prompt injection
 */
export interface CondensedExample {
  taskDescription: string;
  keySteps: string[];
  toolsUsed: string[];
  outcome: string;
  reasoning?: string;
}

/**
 * Similar trajectory result from search
 */
export interface SimilarTrajectory {
  trajectory: TaskTrajectory & {
    steps: TrajectoryStep[];
  };
  similarity: number; // Cosine similarity score
  condensedExample: CondensedExample;
}

/**
 * Search parameters for finding similar trajectories
 */
export interface TrajectorySearchParams {
  taskDescription: string;
  topK?: number;
  minSimilarity?: number;
  modelProvider?: string;
  successOnly?: boolean;
  minQuality?: number;
}

/**
 * Export format for fine-tuning
 */
export interface TrajectoryExport {
  format: 'openai' | 'gemini' | 'anthropic';
  trajectories: ExportedTrajectory[];
  metadata: {
    exportDate: Date;
    totalTrajectories: number;
    successRate: number;
    averageQuality: number;
  };
}

/**
 * Single exported trajectory in fine-tuning format
 */
export interface ExportedTrajectory {
  messages: any[]; // Format-specific message structure
  metadata: {
    taskId: string;
    modelProvider: string;
    success: boolean;
    qualityScore?: number;
  };
}

/**
 * Quality scoring criteria
 */
export interface QualityScoreFactors {
  taskCompleted: boolean; // Base requirement
  noUserInterventions: boolean; // No takeover needed
  efficientExecution: boolean; // Low iteration count
  highClickAccuracy: boolean; // >80% click success
  lowErrorRate: boolean; // <10% tool errors
}

/**
 * Trajectory with related data
 */
export type TrajectoryWithRelations = TaskTrajectory & {
  steps: TrajectoryStep[];
  task: {
    id: string;
    description: string;
    status: string;
  };
};

/**
 * Few-shot example with usage stats
 */
export type FewShotExampleWithStats = FewShotExample & {
  trajectory: {
    modelProvider: string;
    modelName: string;
    qualityScore: number | null;
  };
};
