# MoodLog Support

Developer: early277

Requirements: iPhone running iOS 17 or later

The app's interface is in Japanese. The labels below include the text shown in the app.

## Recording

The recording screen opens when you launch the app. Select a choice to move to the next question. Back (戻る) returns to the previous question. First question (最初へ) returns to the beginning and keeps answers already entered. Tap Record (記録する) on the final screen to save.

When a question can use a previous record, the next button shows the answer that will be used, for example “昨日・多め を使って次へ” (use yesterday / more, then continue). If you do not want to use that answer, clear it with the eraser button at the top.

Voice notes are optional. You can save without a note. You can switch the recognized text between Normal (通常) and Hiragana (ひらがな) display. Hiragana changes how text is displayed; it does not correct speech recognition errors.

## Reviewing and editing

Open Review (振り返り) at the top of the screen.

- Graph (グラフ) shows mood, energy, and answers. Tap an answer cell to see details and Edit (修正).
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

## If voice input is unavailable

Check microphone and speech recognition permissions in iOS Settings. On devices without on-device recognition support, the app uses Apple's speech recognition service, so network availability can affect it. You can record using choices without voice input. To type in a saved note, choose Edit (修正), go to the note, and choose Edit text (文字を修正).

## Problems and contact

Use [GitHub Issues](https://github.com/early277/MoodLog/issues). Include the app version, iPhone model, iOS version, steps to reproduce the problem, and the expected and actual behavior. Posting an issue requires a GitHub account. Using the app does not require an account.

Issues are public. Do not post personal records, notes, audio, or health information. Remove personal information from any screenshots you attach. The developer cannot retrieve data stored in your app.

## Source code and license

The [source code](https://github.com/early277/MoodLog) and original code and assets in this repository are available under the [MIT License](https://github.com/early277/MoodLog/blob/main/LICENSE). Keep the copyright notice and license text when reusing them. Apple's operating systems, frameworks, system fonts, and SF Symbols are subject to Apple's terms; this repository's MIT License grants no rights to those materials. External food-information sources and linked pages are not covered by this MIT License either.

[Privacy Policy](https://github.com/early277/MoodLog/blob/main/PRIVACY_POLICY.md) · [日本語](https://github.com/early277/MoodLog/blob/main/SUPPORT_ja.md)
