import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from '../prisma/prisma.module';
import { TrajectoryRecorderService } from './trajectory-recorder.service';
import { TrajectorySearchService } from './trajectory-search.service';
import { TrajectoryExportService } from './trajectory-export.service';

/**
 * Trajectory Module
 *
 * Provides services for:
 * - Recording task execution trajectories
 * - Searching for similar successful executions
 * - Exporting training data for fine-tuning
 *
 * Enables learning from successful Claude runs to improve other models
 */
@Module({
  imports: [ConfigModule, PrismaModule],
  providers: [
    TrajectoryRecorderService,
    TrajectorySearchService,
    TrajectoryExportService,
  ],
  exports: [
    TrajectoryRecorderService,
    TrajectorySearchService,
    TrajectoryExportService,
  ],
})
export class TrajectoryModule {}
