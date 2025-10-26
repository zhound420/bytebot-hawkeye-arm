import { useEffect, useCallback } from "react";
import { Message, Task } from "@/types";
import { useWebSocketContext } from "@/contexts/WebSocketContext";

interface UseWebSocketProps {
  onTaskUpdate?: (task: Task) => void;
  onNewMessage?: (message: Message) => void;
  onTaskCreated?: (task: Task) => void;
  onTaskDeleted?: (taskId: string) => void;
}

export function useWebSocket({
  onTaskUpdate,
  onNewMessage,
  onTaskCreated,
  onTaskDeleted,
}: UseWebSocketProps = {}) {
  const { socket, isConnected, joinTask, leaveTask, on, off } = useWebSocketContext();

  // Register event handlers
  useEffect(() => {
    if (!socket) return;

    const handleTaskUpdate = (task: Task) => {
      console.log("Task updated:", task);
      onTaskUpdate?.(task);
    };

    const handleNewMessage = (message: Message) => {
      console.log("New message:", message);
      onNewMessage?.(message);
    };

    const handleTaskCreated = (task: Task) => {
      console.log("Task created:", task);
      onTaskCreated?.(task);
    };

    const handleTaskDeleted = (taskId: string) => {
      console.log("Task deleted:", taskId);
      onTaskDeleted?.(taskId);
    };

    // Register handlers
    on("task_updated", handleTaskUpdate);
    on("new_message", handleNewMessage);
    on("task_created", handleTaskCreated);
    on("task_deleted", handleTaskDeleted);

    // Cleanup handlers on unmount
    return () => {
      off("task_updated", handleTaskUpdate);
      off("new_message", handleNewMessage);
      off("task_created", handleTaskCreated);
      off("task_deleted", handleTaskDeleted);
    };
  }, [socket, on, off, onTaskUpdate, onNewMessage, onTaskCreated, onTaskDeleted]);

  const disconnect = useCallback(() => {
    // Note: We don't actually disconnect the singleton socket here
    // Just leave the current task room
    leaveTask();
  }, [leaveTask]);

  return {
    socket,
    joinTask,
    leaveTask,
    disconnect,
    isConnected,
  };
}
