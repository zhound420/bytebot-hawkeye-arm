"use client";

import * as React from "react";
import { Model } from "@/types";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectSeparator,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  groupModelsByProvider,
  getProviderBadgeColor,
} from "@/utils/modelUtils";
import { cn } from "@/lib/utils";

interface ModelSelectProps {
  models: Model[];
  selectedModel: Model | null;
  onModelChange: (model: Model | null) => void;
  className?: string;
}

export function ModelSelect({
  models,
  selectedModel,
  onModelChange,
  className,
}: ModelSelectProps) {
  const groupedModels = React.useMemo(
    () => groupModelsByProvider(models),
    [models]
  );

  return (
    <Select
      value={selectedModel?.name ?? ""}
      onValueChange={(val) =>
        onModelChange(models.find((m) => m.name === val) || null)
      }
    >
      <SelectTrigger className={cn("w-auto", className)}>
        <SelectValue placeholder="Select a model" />
      </SelectTrigger>
      <SelectContent>
        <ScrollArea className="h-[300px]">
          {groupedModels.map((group, groupIndex) => (
            <React.Fragment key={group.category}>
              {groupIndex > 0 && <SelectSeparator />}
              <SelectGroup>
                <SelectLabel className="flex items-center gap-2">
                  <span
                    className={cn(
                      "rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase",
                      getProviderBadgeColor(group.category)
                    )}
                  >
                    {group.category}
                  </span>
                </SelectLabel>
                {group.models.map((model) => (
                  <SelectItem key={model.name} value={model.name}>
                    <div className="flex items-center gap-2">
                      <span>{model.title}</span>
                      {model.supportsVision && (
                        <span className="rounded bg-blue-500/10 px-1.5 py-0.5 text-[9px] font-medium text-blue-600 dark:text-blue-400">
                          Vision
                        </span>
                      )}
                      {model.supportsReasoning && (
                        <span className="rounded bg-amber-500/10 px-1.5 py-0.5 text-[9px] font-medium text-amber-600 dark:text-amber-400">
                          Reasoning
                        </span>
                      )}
                    </div>
                  </SelectItem>
                ))}
              </SelectGroup>
            </React.Fragment>
          ))}
        </ScrollArea>
      </SelectContent>
    </Select>
  );
}
