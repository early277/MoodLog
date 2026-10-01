# MoodLog Privacy Policy

Last updated: October 1, 2026

Developer: early277

MoodLog (気分ログ) is an iPhone app for reviewing your mood, energy, and daily activities. The developer does not operate a server that receives your in-app records.

## Information stored by the app

The app stores the answers you select, record dates and times, optional notes, and custom questions and choices you create. Answers may include mood, energy, sleep times, food, exercise, obligations, events, caffeine, alcohol, tobacco, and other information you choose to enter.

Saved records are stored as JSON in the app's private storage on your device. Draft answers, custom questions, and display preferences are stored in the device's UserDefaults. The app uses this information to display your records, carry forward previous answers, and show charts and comparisons. The developer has no feature for remotely reading this information.

The app has no account registration, advertising, analytics SDKs, tracking, or collection of data from HealthKit.

## Voice input

Voice input is optional. The app requests microphone and speech recognition permission when you use it. You can record answers using choices without using voice input.

Japanese transcription uses Apple's Speech framework. Recognition runs on the device when the device supports it. Otherwise, audio is sent to Apple's speech recognition service for processing. Apple's handling of information is governed by [Apple's Privacy Policy](https://www.apple.com/legal/privacy/).

The app does not save audio files. Recognized text is saved on your device as a note or custom-question input. Hiragana display is a conversion performed on your device; it does not remove the original text. The original transcription is retained even when its hiragana version is displayed.

You can change voice-input permissions in iOS Settings. Revoking permission does not delete text already saved.

## Exports and external links

The share button in the Review screen (振り返り) lets you export saved records as JSON. Exports include answers, notes, record dates and times, and custom-question information contained in those records. You choose the destination in the iOS share sheet. Copies sent or saved elsewhere are subject to the terms and privacy policies of the services or apps you choose.

The app includes external links, such as sources for food information. This policy, support information, and source code are published on GitHub. When you open an external page, that website or your browser provider may process information needed for the connection. Use of GitHub is governed by [GitHub's General Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).

## Retention, editing, and deletion

Saved records remain on your device until you delete them.

- Saved records: open Review (振り返り), select Records (記録), open the relevant record, and choose Edit (修正) or Delete this record (この記録を削除).
- Draft answers: use the eraser button at the top of the relevant question. This also disables carrying forward that answer.
- Notes: use Remove this note (この補足を外す) on the recording screen, or the eraser button in the record editor.
- Custom questions: open question settings using the button at the top, select the question, and choose Delete question (項目を削除). This does not delete answers contained in past records. Edit or delete those records to remove their answers.

The app does not have a button to delete all records at once. Deleting the app using iOS's Delete App action removes its local app data from that device. Offload App keeps its data.

Deleting the app or individual records does not delete files you exported, copies at sharing destinations, or existing iCloud or computer backups. App data may be included in iOS backups, and restoring a backup may restore earlier data. Manage these copies through your backup settings and the relevant services.

## Contact

For problems or questions about this policy, use [GitHub Issues](https://github.com/early277/MoodLog/issues). Issues are public. Do not post personal records, audio, or health information; describe the problem and steps to reproduce it without personal information. The developer cannot access your local records, so editing or deleting them must be performed in the app or through iOS.

[Support](https://github.com/early277/MoodLog/blob/main/SUPPORT.md) · [日本語](https://github.com/early277/MoodLog/blob/main/PRIVACY_POLICY_ja.md)
