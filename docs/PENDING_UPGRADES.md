# ⬆️ 依賴升級紀錄

> ← [Back to README](../README.md)

所有計劃中的 Major 版本升級已全部完成。

---

## 升級路線圖

```mermaid
%%{init: {'theme': 'dark'}}%%
flowchart LR
    S1["第一階段\nRiverpod 3.x\n生態系統"]
    S2["第二階段\nUI 套件"]
    S3["第三階段\n其他 Major"]

    S1 -->|✅| S2 -->|✅| S3

    style S1 fill:#10B981,stroke:#065F46,color:#fff
    style S2 fill:#10B981,stroke:#065F46,color:#fff
    style S3 fill:#10B981,stroke:#065F46,color:#fff
```

---

## ✅ 第一階段：Riverpod 3.x 生態系統

> 2026-02-13 完成

| 套件                    | 版本變更              |
|:----------------------|:------------------|
| flutter_riverpod      | 2.6.1 → 3.2.1     |
| riverpod_annotation   | 2.6.1 → 4.0.2     |
| riverpod_generator    | 2.6.4 → 4.0.3     |
| freezed               | 2.5.8 → 3.2.5     |
| drift                 | 2.28.2 → 2.32.0   |
| dio                   | 5.9.0 → 5.9.2     |
| csv                   | 6.0.0 → 7.2.0     |
| workmanager           | 0.5.2 → 0.9.0+3   |

---

## ✅ 第二階段：UI 套件升級

| 套件               | 版本變更            |
|:-----------------|:----------------|
| fl_chart         | 0.69.0 → 1.1.1  |
| go_router        | 15.1.2 → 17.1.0 |
| flutter_slidable | 3.1.0 → 4.0.3   |

---

## ✅ 第三階段：其他 Major 升級

| 套件                          | 版本變更            |
|:----------------------------|:----------------|
| flutter_local_notifications | 18.x → 21.0.0   |
| flutter_secure_storage      | 9.x → 10.0.0    |
| share_plus                  | 10.x → 12.0.1   |

---

← [Back to README](../README.md) | 📚 [All Documentation](../README.md#文件)

**最後更新**: 2026-03-21
