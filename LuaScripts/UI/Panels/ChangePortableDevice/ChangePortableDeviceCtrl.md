# ChangePortableDeviceCtrl 需求与功能总结

`ChangePortableDeviceCtrl.lua` 当前承载的是一个“随身装置（PortableDevice）在背包与仓库间的专用搬运面板”，核心需求和功能如下。

## 展示与数据结构

- 使用 `UIGroupScrollList` 展示两组数据：`背包`（Group 1）与 `仓库`（Group 2）。
- 背包组按格子顺序显示：`ColoredSlot` + 其中的 `PortableDevice`。
- 仓库组显示所有 `PortableDevice`（排序后）。
- 仅使用 `ItemSlot` 作为 cell，不复用 `ItemBag/Depot` 组件本体逻辑。

## 交互目标

- 仅支持拖拽移动，不支持 Inventory 面板中的：
  - `Ctrl+点击` 快捷移动
  - `Alt+拖拽` 拆分
- 支持三端基础行为：
  - 点击显示 `ItemTips`
  - 手柄优先走 `ActionMenu`
  - 拖拽时统一高亮与落点反馈
- 支持三类移动：
  - 背包 -> 仓库
  - 仓库 -> 背包
  - 背包内移动

## 临时空格与高亮逻辑（重点）

- 背包拖拽期间可增量生成/回收临时空格（append/remove），用于落点引导。
- 仓库组在拖拽高亮时：
  - 若存在同 ID 道具，直接高亮该格
  - 若不存在，末尾增量生成仓库临时空格并高亮
- 当背包没有非 `ColoredSlot` 空格时，仍会生成“无效临时格”：
  - 显示 `invalidHint`
  - 若落到该格，弹出 `LUA_ITEM_BAG_PORTABLE_DEVICE_NO_EXTRA_SLOT`

## 业务规则细节

- 仓库拖到背包非空 `ColoredSlot` 时：
  - 优先尝试将目标格道具挪到背包普通空格
  - 若无空位则先回仓库
  - 再把拖拽道具放入该 `ColoredSlot`
  - 分别提示：
    - `LUA_ITEM_BAG_PORTABLE_DEVICE_REPLACED_TO_BAG`
    - `LUA_ITEM_BAG_PORTABLE_DEVICE_TARGET_BACK_TO_DEPOT`
  - 两条提示已支持道具名 `%s` 占位

## 稳定性与事件

- 只监听：
  - `ON_ITEM_BAG_CHANGED`
  - `ON_SYNC_INVENTORY`
  - 拖拽开始/结束消息
- 使用 `m_dropCommandHandledInCurrentDrag` 防止单次拖拽重复触发多次 drop。
- 拖拽时动态提升 Depot `GroupBG` 层级，结束后恢复，确保组级落区优先响应。

## 当前代码约束与风格

- 已进行 `region` 分区整理，注释中文为主，保留关键英文术语。
- `self.m_itemBag` 在当前实现中按“始终非空”前提处理。

