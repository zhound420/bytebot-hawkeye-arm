-- Enable pgvector extension for vector similarity search
CREATE EXTENSION IF NOT EXISTS vector;

-- CreateTable
CREATE TABLE "TaskTrajectory" (
    "id" TEXT NOT NULL,
    "taskId" TEXT NOT NULL,
    "modelProvider" TEXT NOT NULL,
    "modelName" TEXT NOT NULL,
    "success" BOOLEAN NOT NULL,
    "qualityScore" DOUBLE PRECISION,
    "iterationCount" INTEGER NOT NULL DEFAULT 0,
    "toolCallsCount" INTEGER NOT NULL DEFAULT 0,
    "tokenUsageInput" INTEGER NOT NULL DEFAULT 0,
    "tokenUsageOutput" INTEGER NOT NULL DEFAULT 0,
    "tokenUsageTotal" INTEGER NOT NULL DEFAULT 0,
    "errorRate" DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    "clickAccuracy" DOUBLE PRECISION,
    "userInterventions" INTEGER NOT NULL DEFAULT 0,
    "startedAt" TIMESTAMP(3) NOT NULL,
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TaskTrajectory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrajectoryStep" (
    "id" TEXT NOT NULL,
    "trajectoryId" TEXT NOT NULL,
    "iterationNumber" INTEGER NOT NULL,
    "systemPrompt" TEXT NOT NULL,
    "messagesSnapshot" JSONB NOT NULL,
    "toolCalls" JSONB,
    "toolResults" JSONB,
    "reasoning" TEXT,
    "tokenUsageInput" INTEGER NOT NULL DEFAULT 0,
    "tokenUsageOutput" INTEGER NOT NULL DEFAULT 0,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TrajectoryStep_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrajectoryEmbedding" (
    "id" TEXT NOT NULL,
    "trajectoryId" TEXT NOT NULL,
    "taskDescription" TEXT NOT NULL,
    "embedding" vector(1536),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TrajectoryEmbedding_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FewShotExample" (
    "id" TEXT NOT NULL,
    "trajectoryId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "condensedContent" TEXT NOT NULL,
    "taskType" TEXT,
    "difficulty" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "usageCount" INTEGER NOT NULL DEFAULT 0,
    "lastUsedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FewShotExample_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "TaskTrajectory_taskId_key" ON "TaskTrajectory"("taskId");

-- CreateIndex
CREATE INDEX "TaskTrajectory_modelProvider_success_idx" ON "TaskTrajectory"("modelProvider", "success");

-- CreateIndex
CREATE INDEX "TaskTrajectory_qualityScore_idx" ON "TaskTrajectory"("qualityScore");

-- CreateIndex
CREATE INDEX "TaskTrajectory_startedAt_idx" ON "TaskTrajectory"("startedAt");

-- CreateIndex
CREATE INDEX "TrajectoryStep_trajectoryId_iterationNumber_idx" ON "TrajectoryStep"("trajectoryId", "iterationNumber");

-- CreateIndex
CREATE UNIQUE INDEX "TrajectoryEmbedding_trajectoryId_key" ON "TrajectoryEmbedding"("trajectoryId");

-- CreateIndex
CREATE INDEX "TrajectoryEmbedding_taskDescription_idx" ON "TrajectoryEmbedding"("taskDescription");

-- CreateIndex
CREATE INDEX "FewShotExample_taskType_isActive_idx" ON "FewShotExample"("taskType", "isActive");

-- CreateIndex
CREATE INDEX "FewShotExample_usageCount_idx" ON "FewShotExample"("usageCount");

-- AddForeignKey
ALTER TABLE "TaskTrajectory" ADD CONSTRAINT "TaskTrajectory_taskId_fkey" FOREIGN KEY ("taskId") REFERENCES "Task"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrajectoryStep" ADD CONSTRAINT "TrajectoryStep_trajectoryId_fkey" FOREIGN KEY ("trajectoryId") REFERENCES "TaskTrajectory"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrajectoryEmbedding" ADD CONSTRAINT "TrajectoryEmbedding_trajectoryId_fkey" FOREIGN KEY ("trajectoryId") REFERENCES "TaskTrajectory"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FewShotExample" ADD CONSTRAINT "FewShotExample_trajectoryId_fkey" FOREIGN KEY ("trajectoryId") REFERENCES "TaskTrajectory"("id") ON DELETE CASCADE ON UPDATE CASCADE;
