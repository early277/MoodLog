# MoodLog Support

Developer: early277

Requirements: iPhone running iOS 17 or later

The interface supports Japanese, English, Simplified Chinese, Korean, Spanish, and Brazilian Portuguese, following the iOS app language. User-authored notes, custom questions, and choices are not automatically translated. The Japanese labels below identify the corresponding controls.

## Recording

The recording screen opens when you launch the app. Select a choice to move to the next question. Back (戻る) returns to the previous question. First question (最初へ) returns to the beginning and keeps answers already entered. Tap Record (記録する) on the final screen to save. A successful save opens the latest Graph in Review.

When a question can use a previous record, the next button shows the answer that will be used, for example “昨日・多め を使って次へ” (use yesterday / more, then continue). Use “未回答で次へ” (continue without an answer) to leave it blank. Previous answers are carried only when you tap the button showing that answer. Returning to a question keeps its selected answer available. Saving does not automatically fill unseen questions.

Version 0.1.19 and later has no in-app voice input. Earlier notes are preserved and can be viewed or edited through Review.

For main sleep (excluding naps), confirm the bedtime and wake dates beside the clock. Reused clock values are confirmed for the current target dates; the original dates appear in the candidate. The bedtime-to-wake interval is not actual time asleep. Older records with unknown sleep dates remain unknown. Caffeine, alcohol, and tobacco periods use elapsed-hour ranges (a day is 24 hours); other recency questions use calendar days.

## Reviewing and editing

Open Review (振り返り) at the top of the screen.

- Graph (グラフ) shows mood, energy, and answers. Tap an answer cell for details; hold it for 0.6 seconds to edit that item.
- Compare (比較) lets you choose a question and see average mood and energy for each answer, with the number of recorded days.
- Records (記録) shows individual records. Use the arrows to select a record and choose Edit (修正) to change it.

In the record editor, select replacement answers and tap Save (保存) at the top. Cancel (取消) discards the changes. Editing does not change the record's date and time. For notes, Edit text (文字を修正) enables keyboard editing.

Charts and comparisons summarize your own records. The app does not determine causes, diagnose or treat conditions, or make decisions about medication or nutrient intake.

## Deleting and exporting

- Draft answer: use the eraser button at the top of that question.
- Saved answer: open Edit (修正) for the record, use the eraser on the relevant question, and tap Save (保存).
- Saved record: Review (振り返り) → Records (記録) → relevant record → Delete this record (この記録を削除) → Delete (削除する).
- Custom question: open question settings using the button at the top, select the question, and choose Delete question (項目を削除). Past answers remain in saved records.
- Export: use the share button at the top left of Review (振り返り) and choose a destination. Records are exported as JSON. The current app does not import JSON files.

The app does not have a bulk-delete button for all records. iOS's Delete App action removes local app data from that device; Offload App preserves it. Manage exported files and existing backups separately.

## Problems and contact

Use [GitHub Issues](https://github.com/early277/MoodLog/issues). Include the app version, iPhone model, iOS version, steps to reproduce the problem, and the expected and actual behavior. Posting an issue requires a GitHub account. Using the app does not require an account.

Issues are public. Do not post personal records, notes, audio, or health information. Remove personal information from any screenshots you attach. The developer cannot retrieve data stored in your app.

## Source code and license

The [source code](https://github.com/early277/MoodLog) and original code and assets in this repository are available under the [MIT License](https://github.com/early277/MoodLog/blob/main/LICENSE). Keep the copyright notice and license text when reusing them. Apple's operating systems, frameworks, system fonts, and SF Symbols are subject to Apple's terms; this repository's MIT License grants no rights to those materials. External food-information sources and linked pages are not covered by this MIT License either.

[Privacy Policy](https://github.com/early277/MoodLog/blob/main/PRIVACY_POLICY.md) · [日本語](https://github.com/early277/MoodLog/blob/main/SUPPORT_ja.md)
