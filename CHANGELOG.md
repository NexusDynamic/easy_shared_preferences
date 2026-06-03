## 1.1.2

* Migrated exmaple away from KGP
* Updated `build.gradle.kts` to use `JvmTarget.JVM_17`
* Updated gradle wrapper to `9.1.0`
* Updated `shared_preferences` to `^2.5.5`
* Updated IOS example

## 1.1.1

Added `fromJson` and `fromMap` factory constructors to `Setting`, `SettingsGroup` and `GroupConfig` classes for easier deserialization from JSON strings.
Added `toJson` and `toMap` in `Setting`, `SettingsGroup` and `GroupConfig`.
Added `SettingFactory` class to easily create `Setting` instances from maps / json.

## 1.1.0

* **Breaking**: Renamed `Settings` to `EasySettings` to avoid potential conflicts with a commonly used name.

## 1.0.1

* Updated `shared_preferences` and `logging` dependencies

## 1.0.0

* Version 1.0.0 release
* Extracted code from another project and added more testing and tweaked the API
