/**
 * Backfill embeddings for existing trajectories
 *
 * This script generates and stores embeddings for trajectories that were
 * created before the embedding integration was added.
 */

import { PrismaClient } from '@prisma/client';
import OpenAI from 'openai';

const prisma = new PrismaClient();

async function backfillEmbeddings() {
  console.log('🔍 Finding trajectories without embeddings...\n');

  // Find all trajectories that don't have embeddings
  const trajectories = await prisma.taskTrajectory.findMany({
    where: {
      embedding: null,
    },
    include: {
      task: {
        select: {
          description: true,
        },
      },
    },
  });

  console.log(`Found ${trajectories.length} trajectories without embeddings\n`);

  if (trajectories.length === 0) {
    console.log('✅ All trajectories already have embeddings!');
    await prisma.$disconnect();
    return;
  }

  // Initialize OpenAI client
  const apiKey = process.env.OPENAI_API_KEY || process.env.BYTEBOT_EMBEDDING_API_KEY;
  if (!apiKey) {
    console.error('❌ Error: OPENAI_API_KEY or BYTEBOT_EMBEDDING_API_KEY environment variable not set');
    await prisma.$disconnect();
    process.exit(1);
  }

  const openai = new OpenAI({ apiKey });
  const embeddingModel = 'text-embedding-3-small'; // 1536 dimensions

  console.log(`Using embedding model: ${embeddingModel}\n`);

  let successCount = 0;
  let errorCount = 0;

  for (const trajectory of trajectories) {
    const taskDescription = trajectory.task?.description;

    if (!taskDescription) {
      console.log(`⚠️  Skipping trajectory ${trajectory.id} (no task description)`);
      continue;
    }

    try {
      console.log(`Generating embedding for: "${taskDescription.slice(0, 60)}..."`);

      // Generate embedding
      const response = await openai.embeddings.create({
        model: embeddingModel,
        input: taskDescription,
      });

      const embedding = response.data[0].embedding;

      // Store in database using raw SQL (pgvector)
      await prisma.$executeRaw`
        INSERT INTO "TrajectoryEmbedding" (id, "trajectoryId", "taskDescription", embedding, "createdAt", "updatedAt")
        VALUES (gen_random_uuid(), ${trajectory.id}, ${taskDescription}, ${embedding}::vector, NOW(), NOW())
        ON CONFLICT ("trajectoryId") DO UPDATE
        SET "taskDescription" = ${taskDescription},
            embedding = ${embedding}::vector,
            "updatedAt" = NOW()
      `;

      console.log(`✅ Stored embedding for trajectory ${trajectory.id.slice(0, 8)}... (${trajectory.modelProvider}/${trajectory.modelName})\n`);
      successCount++;
    } catch (error) {
      console.error(`❌ Failed to process trajectory ${trajectory.id}: ${error.message}\n`);
      errorCount++;
    }
  }

  console.log('\n📊 Summary:');
  console.log(`   ✅ Successfully processed: ${successCount}`);
  console.log(`   ❌ Errors: ${errorCount}`);
  console.log(`   📝 Total: ${trajectories.length}`);

  await prisma.$disconnect();
}

backfillEmbeddings().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
