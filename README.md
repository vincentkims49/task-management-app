# TaskFlow - Flutter Task Management App

A comprehensive task management application built with Flutter that allows users to organize their tasks, sync across multiple devices, collaborate with others, and visualize their schedule through an intuitive calendar interface.

![Task Management App](https://drive.google.com/file/d/15XYFs4E2MeNGuC8mUGoGYNvYneVlwYuY/view?usp=drivesdk)

## Features

### Core Features
- ✅ User Authentication (Email/Password and Google Sign-In)
- ✅ Task Creation, Editing, and Deletion
- ✅ Task Categories with Priority Levels
- ✅ Subtasks for Complex Task Management
- ✅ Dark/Light Theme Support


### Advanced Features
- ✅ **Cloud Synchronization**: Access tasks across multiple devices with offline support
- ✅ **Calendar View**: Visualize tasks with due dates in daily/monthly views
- ✅ **Task Sharing**: Collaborate with others on shared tasks in real-time

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0.0 or later)
- Dart SDK (3.0.0 or later)
- Android Studio / VS Code with Flutter extensions
- Firebase account
- Git

### Step 1: Clone the Repository
```bash
git clone https://github.com/yourusername/taskflow.git
cd taskflow
```

### Step 2: Install Dependencies
```bash
flutter pub get
```

### Step 3: Firebase Setup

#### Using Firebase CLI (Recommended)
1. Install Firebase CLI and Flutter Fire CLI:
```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

2. Login to Firebase:
```bash
firebase login
```

3. Initialize Firebase in your project:
```bash
flutterfire configure
```
This interactive command will:
- Allow you to select a Firebase project
- Register your app with Firebase
- Download configuration files
- Generate a `firebase_options.dart` file

#### Manual Setup (Alternative)
1. Create a new Firebase project in the [Firebase Console](https://console.firebase.google.com/)
2. Register your app (Android & iOS)
3. Download configuration files:
   - `google-services.json` (Android) -> place in `android/app/`
4. Update build files as described in Firebase documentation

### Step 4: Configure Authentication
1. In Firebase Console, go to Authentication → Sign-in method
2. Enable Email/Password and Google Sign-In methods
3. For Google Sign-In on Android, add your SHA-1 fingerprint:
```bash
cd android && ./gradlew signingReport
```

### Step 5: Set Up Firestore
1. In Firebase Console, create a Firestore database
2. Start in production mode
3. Configure Firestore rules (use the rules provided in the `firestore.rules` file)
4. Create necessary indices for complex queries:
   - Collection: `tasks` | Fields: `userId` (Ascending) + `sharedWith` (Ascending) + `__name__` (Ascending)

### Step 6: Run the App
```bash
flutter run
```

## Technical Approach

### Architecture
The app follows a layered architecture with clean separation of concerns:

- **Presentation Layer**: UI components and screens
- **Business Logic Layer**: BLoC pattern for state management
- **Data Layer**: Repositories and data sources
- **Domain Layer**: Models and business entities

### State Management
The app uses the BLoC (Business Logic Component) pattern for state management, which provides:
- Predictable state transitions
- Testable business logic
- Separation of UI and business logic
- Reactive programming model

### Data Flow
1. User interactions trigger events in BLoC
2. BLoC processes events and updates state
3. UI rebuilds based on new state
4. For data persistence, BLoC interacts with repositories
5. Repositories manage data from different sources (local storage and Firestore)

### Offline Support
The app implements a robust offline-first approach:
1. All changes are saved locally first
2. When online, changes are synced to Firestore
3. If offline, pending operations are queued
4. When connectivity is restored, queued operations are executed
5. Conflicts are resolved with a deterministic merge strategy


## Technologies Used

- **Flutter**: UI framework
- **Firebase**:
  - Authentication: User management
  - Firestore: Cloud database and sync
- **flutter_bloc**: State management
- **Hive**: Local storage
- **table_calendar**: Calendar visualization
- **flutter_slidable**: Swipe actions for tasks
- **intl**: Internationalization and date formatting
- **connectivity_plus**: Network connectivity monitoring
- **flutter_local_notifications**: Push notifications
- **google_sign_in**: Google authentication

## Implementation Challenges and Solutions

### Cloud Synchronization
- **Challenge**: Handling offline-to-online transitions with potential conflicts
- **Solution**: Implemented a queue-based system for pending operations with timestamp-based conflict resolution

### Calendar View Performance
- **Challenge**: Optimizing performance with many tasks
- **Solution**: Lazy loading of tasks and efficient rendering of calendar markers

### Task Sharing Security
- **Challenge**: Ensuring proper access control
- **Solution**: Granular Firestore security rules that protect data while enabling collaboration

## Project Structure

```
lib
├── app.dart
├── assets
│   ├── animations
│   │   └── empty_tasks.json
│   ├── icon
│   │   └── app_icon.png
│   └── images
├── blocs
│   ├── auth
│   │   ├── auth_bloc.dart
│   │   ├── auth_event.dart
│   │   └── auth_state.dart
│   ├── tasks
│   │   ├── task_bloc.dart
│   │   ├── task_event.dart
│   │   └── task_state.dart
│   └── theme
│       ├── theme_bloc.dart
│       ├── theme_event.dart
│       └── theme_state.dart
├── core
│   ├── di
│   │   └── service_locator.dart
│   └── routes.dart
├── data
│   ├── models
│   │   ├── subtask.dart
│   │   ├── subtask.g.dart
│   │   ├── task.dart
│   │   ├── task_filter.dart
│   │   ├── task.g.dart
│   │   └── user_profile.dart
│   ├── repositories
│   │   ├── auth_repository.dart
│   │   ├── task_repository.dart
│   │   └── user_repository.dart
│   └── services
│       ├── network
│       │   └── connectivity_service.dart
│       ├── storage
│       │   ├── firebase_auth_service.dart
│       │   ├── firestore_service.dart
│       │   └── local_storage_service.dart
│       └── tasks
│           └── task_sharing_service.dart
├── main.dart
├── navigation
│   ├── auth_wrapper.dart
│   └── screens
│       ├── bottom_navigation.dart
│       └── main_navigation_screen.dart
├── ui
│   ├── screens
│   │   ├── auth
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── settings
│   │   │   └── settings_screen.dart
│   │   └── tasks
│   │       ├── calendar_screen.dart
│   │       ├── shared_tasks_screen.dart
│   │       ├── task_detail_screen.dart
│   │       ├── task_form_screen.dart
│   │       └── task_list_screen.dart
│   ├── theme
│   │   ├── app_theme.dart
│   │   └── theme_constants.dart
│   └── widgets
│       ├── common
│       │   ├── custom_text_field.dart
│       │   ├── date_picker.dart
│       │   └── social_login_button.dart
│       └── tasks
│           ├── month_overview.dart
│           ├── priority_badge.dart
│           ├── priority_selector.dart
│           ├── share_task_dialog.dart
│           ├── subtask_list.dart
│           ├── subtask_tile.dart
│           ├── task_card.dart
│           ├── task_filter_bottom_sheet.dart
│           └── task_search_delegate.dart
└── utils
    ├── date_utils.dart
    ├── notification_helper.dart
    └── validators.dart
```

Developed by **VINCENT KIMNAZI (FLUTTER DEV)**