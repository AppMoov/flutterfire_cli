/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:path/path.dart' as path;

import '../common/platform.dart';
import '../common/prompts.dart';
import '../common/strings.dart';
import '../common/utils.dart';
import '../firebase.dart' as firebase;
import '../firebase/firebase_android_gradle_plugins.dart';
import '../firebase/firebase_android_options.dart';
import '../firebase/firebase_apple_options.dart';
import '../firebase/firebase_apple_setup.dart';
import '../firebase/firebase_configuration_file.dart';
import '../firebase/firebase_options.dart';
import '../firebase/firebase_project.dart';
import '../firebase/firebase_web_options.dart';
import '../flutter_app.dart';
import 'base.dart';

class ConfigCommand extends FlutterFireCommand {
  ConfigCommand(FlutterApp? flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();
    argParser.addOption(
      kOutFlag,
      valueHelp: 'filePath',
      defaultsTo: 'lib${currentPlatform.pathSeparator}firebase_options.dart',
      abbr: 'o',
      help: 'The output file path of the Dart file that will be generated with '
          'your Firebase configuration options.',
    );
    argParser.addFlag(
      kYesFlag,
      abbr: 'y',
      negatable: false,
      help:
          'Skip the Y/n confirmation prompts and accept default options (such as detected platforms).',
    );
    argParser.addOption(
      kPlatformsFlag,
      valueHelp: 'platforms',
      mandatory: isCI,
      help:
          'Optionally specify the platforms to generate configuration options for '
          'as a comma separated list. For example "android,ios,macos,web,linux,windows".',
    );
    argParser.addOption(
      kIosBundleIdFlag,
      valueHelp: 'bundleIdentifier',
      mandatory: isCI,
      abbr: 'i',
      help: 'The bundle identifier of your iOS app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "ios" folder (if it exists).',
    );
    argParser.addOption(
      kMacosBundleIdFlag,
      valueHelp: 'bundleIdentifier',
      mandatory: isCI,
      abbr: 'm',
      help: 'The bundle identifier of your macOS app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "macos" folder (if it exists).',
    );
    argParser.addOption(
      kAndroidAppIdFlag,
      valueHelp: 'applicationId',
      help:
          'DEPRECATED - use "android-package-name" instead. The application id of your Android app, e.g. "com.example.app". '
          'If no identifier is provided then an attempt will be made to '
          'automatically detect it from your "android" folder (if it exists)',
    );
    argParser.addOption(
      kAndroidPackageNameFlag,
      valueHelp: 'packageName',
      abbr: 'a',
      help: 'The package name of your Android app, e.g. "com.example.app". '
          'If no package name is provided then an attempt will be made to '
          'automatically detect it from your "android" folder (if it exists).',
    );
    argParser.addOption(
      kWebAppIdFlag,
      valueHelp: 'appId',
      abbr: 'w',
      help: 'The app id of your Web application, e.g. "1:XXX:web:YYY". '
          'If no package name is provided then an attempt will be made to '
          'automatically pick the first available web app id from remote.',
    );
    argParser.addOption(
      kTokenFlag,
      valueHelp: 'firebaseToken',
      abbr: 't',
      help: 'The token generated by running `firebase login:ci`',
    );
    argParser.addFlag(
      kAppleGradlePluginFlag,
      defaultsTo: true,
      hide: true,
      abbr: 'g',
      help:
          "Whether to add the Firebase related Gradle plugins (such as Crashlytics and Performance) to your Android app's build.gradle files "
          'and create the google-services.json file in your ./android/app folder.',
    );

    argParser.addOption(
      kIosBuildConfigFlag,
      valueHelp: 'iosBuildConfiguration',
      help:
          'Name of iOS build configuration to use for bundling `Google-Service-Info.plist` with your Xcode project',
    );

    argParser.addOption(
      kMacosBuildConfigFlag,
      valueHelp: 'macosBuildConfiguration',
      help:
          'Name of macOS build configuration to use for bundling `Google-Service-Info.plist` with your Xcode project',
    );

    argParser.addOption(
      kIosTargetFlag,
      valueHelp: 'iosTargetName',
      help:
          'Name of iOS target to use for bundling `Google-Service-Info.plist` with your Xcode project',
    );

    argParser.addOption(
      kMacosTargetFlag,
      valueHelp: 'macosTargetName',
      help:
          'Name of macOS target to use for bundling `Google-Service-Info.plist` with your Xcode project',
    );

    argParser.addOption(
      kIosOutFlag,
      valueHelp: 'pathForIosConfig',
      help:
          'Where to write the `Google-Service-Info.plist` file for iOS platform. Useful for different flavors',
    );

    argParser.addOption(
      kMacosOutFlag,
      valueHelp: 'pathForMacosConfig',
      help:
          'Where to write the `Google-Service-Info.plist` file to be written for macOS platform. Useful for different flavors',
    );

    argParser.addOption(
      kAndroidOutFlag,
      valueHelp: 'pathForAndroidConfig',
      help:
          'Where to write the `google-services.json` file to be written for android platform. Useful for different flavors',
    );

    argParser.addFlag(
      kOverwriteFirebaseOptionsFlag,
      abbr: 'f',
      defaultsTo: null,
      help:
          "Rewrite the service file if you're running 'flutterfire configure' again due to updating project",
    );
  }

  @override
  final String name = 'configure';

  @override
  List<String> aliases = <String>[
    'c',
    'config',
  ];

  @override
  final String description = 'Configure Firebase for your Flutter app. This '
      'command will fetch Firebase configuration for you and generate a '
      'Dart file with prefilled FirebaseOptions you can use.';

  bool get yes {
    return argResults!['yes'] as bool || false;
  }

  List<String> get platforms {
    final platformsString = argResults!['platforms'] as String?;
    if (platformsString == null || platformsString.isEmpty) {
      return <String>[];
    }
    return platformsString
        .split(',')
        .map((String platform) => platform.trim().toLowerCase())
        .where(
          (element) =>
              element == 'ios' ||
              element == 'android' ||
              element == 'macos' ||
              element == 'web' ||
              element == 'linux' ||
              element == 'windows',
        )
        .toList();
  }

  bool get applyGradlePlugins {
    return argResults!['apply-gradle-plugins'] as bool;
  }

  String? get iosBuildConfiguration {
    return argResults!['ios-build-config'] as String?;
  }

  String? get macosBuildConfiguration {
    return argResults!['macos-build-config'] as String?;
  }

  String? get iosTarget {
    return argResults!['ios-target'] as String?;
  }

  String? get macosTarget {
    return argResults!['macos-target'] as String?;
  }

  String? get macOSServiceFilePath {
    return argResults!['macos-out'] as String?;
  }

  String? get iOSServiceFilePath {
    return argResults!['ios-out'] as String?;
  }

  String? get androidServiceFilePath {
    final serviceFilePath = argResults!['android-out'] as String?;
    if (serviceFilePath == null) {
      return null;
    }

    final segments = path.split(serviceFilePath);

    if (!segments.contains('android') || !segments.contains('app')) {
      throw ServiceFileException(
        kAndroid,
        'The service file name must contain `android/app`. See documentation for more information: https://firebase.google.com/docs/projects/multiprojects',
      );
    }

    final basename = path.basename(serviceFilePath);

    if (basename == androidServiceFileName) {
      return removeForwardBackwardSlash(serviceFilePath);
    }

    if (basename.contains('.')) {
      throw ServiceFileException(
        kAndroid,
        'The service file name must be `$androidServiceFileName`. Please provide a path to the file. e.g. `android/app/development` or `android/app/development/$androidServiceFileName`',
      );
    }
    return path.join(
      removeForwardBackwardSlash(serviceFilePath),
      androidServiceFileName,
    );
  }

  String? get androidApplicationId {
    final value = argResults!['android-package-name'] as String?;
    final deprecatedValue = argResults!['android-app-id'] as String?;

    // TODO validate packagename is valid if provided.

    if (value != null) {
      return value;
    }
    if (deprecatedValue != null) {
      logger.stdout(
        'Warning - android-app-id (-a) is deprecated. Consider using android-package-name (-p) instead.',
      );
      return deprecatedValue;
    }

    if (isCI) {
      throw FirebaseCommandException(
        'configure',
        'Please provide value for android-package-name.',
      );
    }
    return null;
  }

  String? get iosBundleId {
    final value = argResults!['ios-bundle-id'] as String?;
    // TODO validate bundleId is valid if provided
    return value;
  }

  String? get webAppId {
    final value = argResults!['web-app-id'] as String?;

    if (value != null) return value;

    if (isCI) {
      throw FirebaseCommandException(
        'configure',
        'Please provide value for web-app-id.',
      );
    }
    return null;
  }

  String? get macosBundleId {
    final value = argResults!['macos-bundle-id'] as String?;
    // TODO validate bundleId is valid if provided
    return value;
  }

  String? get token {
    final value = argResults!['token'] as String?;
    return value;
  }

  String get outputFilePath {
    return argResults!['out'] as String;
  }

  bool? get overwriteFirebaseOptions {
    return argResults!['overwrite-firebase-options'] as bool?;
  }

  String get iosAppIDOutputFilePrefix {
    return 'ios';
  }

  String get macosAppIDOutputFilePrefix {
    return 'macos';
  }

  String get androidAppIDOutputFilePrefix {
    return 'android';
  }

  AppleResponses? macosInputs;
  AppleResponses? iosInputs;

  Future<FirebaseProject> _promptCreateFirebaseProject() async {
    final newProjectId = promptInput(
      'Enter a project id for your new Firebase project (e.g. ${AnsiStyles.cyan('my-cool-project')})',
      validator: (String x) {
        if (RegExp(r'^[a-zA-Z0-9\-]+$').hasMatch(x)) {
          return true;
        } else {
          return 'Firebase project ids must be lowercase and contain only alphanumeric and dash characters.';
        }
      },
    );
    final creatingProjectSpinner = spinner(
      (done) {
        if (!done) {
          return 'Creating new Firebase project ${AnsiStyles.cyan(newProjectId)}...';
        }
        return 'New Firebase project ${AnsiStyles.cyan(newProjectId)} created successfully.';
      },
    );
    final newProject = await firebase.createProject(
      projectId: newProjectId,
      account: accountEmail,
      token: token,
    );
    creatingProjectSpinner.done();
    return newProject;
  }

  Future<FirebaseProject> _selectFirebaseProject() async {
    var selectedProjectId = projectId;
    selectedProjectId ??= await firebase.getDefaultFirebaseProjectId();

    if ((isCI || yes) && selectedProjectId == null) {
      throw FirebaseProjectRequiredException();
    }

    List<FirebaseProject>? firebaseProjects;

    final fetchingProjectsSpinner = spinner(
      (done) {
        if (!done) {
          return 'Fetching available Firebase projects...';
        }
        final baseMessage =
            'Found ${AnsiStyles.cyan('${firebaseProjects?.length ?? 0}')} Firebase projects.';
        if (selectedProjectId != null) {
          return '$baseMessage Selecting project ${AnsiStyles.cyan(selectedProjectId)}.';
        }
        return baseMessage;
      },
    );
    firebaseProjects = await firebase.getProjects(
      account: accountEmail,
      token: token,
    );

    fetchingProjectsSpinner.done();
    if (selectedProjectId != null) {
      return firebaseProjects.firstWhere(
        (project) => project.projectId == selectedProjectId,
        orElse: () {
          throw FirebaseProjectNotFoundException(selectedProjectId!);
        },
      );
    }

    // No projects to choose from so lets
    // prompt to create straight away.
    if (firebaseProjects.isEmpty) {
      return _promptCreateFirebaseProject();
    }

    final choices = <String>[
      ...firebaseProjects.map(
        (p) => '${p.projectId} (${p.displayName})',
      ),
      AnsiStyles.green('<create a new project>'),
    ];

    final selectedChoiceIndex = promptSelect(
      'Select a Firebase project to configure your Flutter application with',
      choices,
    );

    // Last choice is to create a new project.
    if (selectedChoiceIndex == choices.length - 1) {
      return _promptCreateFirebaseProject();
    }

    return firebaseProjects[selectedChoiceIndex];
  }

  Map<String, bool> _selectPlatforms() {
    final selectedPlatforms = <String, bool>{
      kAndroid: platforms.contains(kAndroid) ||
          platforms.isEmpty && flutterApp!.android,
      kIos: platforms.contains(kIos) || platforms.isEmpty && flutterApp!.ios,
      kMacos:
          platforms.contains(kMacos) || platforms.isEmpty && flutterApp!.macos,
      kWeb: platforms.contains(kWeb) || platforms.isEmpty && flutterApp!.web,
      if (flutterApp!.dependsOnPackage('firebase_core_desktop'))
        kWindows: platforms.contains(kWindows) ||
            platforms.isEmpty && flutterApp!.windows,
      if (flutterApp!.dependsOnPackage('firebase_core_desktop'))
        kLinux: platforms.contains(kLinux) ||
            platforms.isEmpty && flutterApp!.linux,
    };
    if (platforms.isNotEmpty || isCI || yes) {
      final selectedPlatformsString = selectedPlatforms.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList()
          .join(',');
      logger.stdout(
        AnsiStyles.bold(
          '${AnsiStyles.blue('i')} Selected platforms: ${AnsiStyles.green(selectedPlatformsString)}',
        ),
      );
      return selectedPlatforms;
    }
    final answers = promptMultiSelect(
      'Which platforms should your configuration support (use arrow keys & space to select)?',
      selectedPlatforms.keys.toList(),
      defaultSelection: selectedPlatforms.values.toList(),
    );
    var index = 0;
    for (final key in selectedPlatforms.keys) {
      if (answers.contains(index)) {
        selectedPlatforms[key] = true;
      } else {
        selectedPlatforms[key] = false;
      }
      index++;
    }
    return selectedPlatforms;
  }

  @override
  Future<void> run() async {
    commandRequiresFlutterApp();

    // Prompts first
    if (Platform.isMacOS) {
      macosInputs = await applePrompts(
        platform: kMacos,
        flutterAppPath: flutterApp!.package.path,
        serviceFilePath: macOSServiceFilePath,
        target: macosTarget,
        buildConfiguration: macosBuildConfiguration,
      );
      iosInputs = await applePrompts(
        platform: kIos,
        flutterAppPath: flutterApp!.package.path,
        serviceFilePath: iOSServiceFilePath,
        target: iosTarget,
        buildConfiguration: iosBuildConfiguration,
      );
    }

    if (flutterApp!.android) {
      // TODO make prompt for service file
    }

    final selectedFirebaseProject = await _selectFirebaseProject();
    final selectedPlatforms = _selectPlatforms();

    if (!selectedPlatforms.containsValue(true)) {
      throw NoFlutterPlatformsSelectedException();
    }

    // Write this early so it can be used in whatever setup has been configured
    await writeFirebaseJsonFile(flutterApp!);

    FirebaseOptions? androidOptions;
    if (selectedPlatforms[kAndroid]!) {
      androidOptions = await FirebaseAndroidOptions.forFlutterApp(
        flutterApp!,
        androidApplicationId: androidApplicationId,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
        token: token,
      );
    }

    FirebaseOptions? iosOptions;
    if (selectedPlatforms[kIos]!) {
      iosOptions = await FirebaseAppleOptions.forFlutterApp(
        flutterApp!,
        appleBundleIdentifier: iosBundleId,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
        token: token,
      );
    }

    FirebaseOptions? macosOptions;
    if (selectedPlatforms[kMacos]!) {
      macosOptions = await FirebaseAppleOptions.forFlutterApp(
        flutterApp!,
        appleBundleIdentifier: macosBundleId,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
        macos: true,
        token: token,
      );
    }

    FirebaseOptions? webOptions;
    if (selectedPlatforms[kWeb]!) {
      webOptions = await FirebaseWebOptions.forFlutterApp(
        flutterApp!,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
        token: token,
        webAppId: webAppId,
      );
    }

    FirebaseOptions? windowsOptions;
    if (selectedPlatforms[kWindows] != null && selectedPlatforms[kWindows]!) {
      windowsOptions = await FirebaseWebOptions.forFlutterApp(
        flutterApp!,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
        platform: kWindows,
        token: token,
      );
    }

    FirebaseOptions? linuxOptions;
    if (selectedPlatforms[kLinux] != null && selectedPlatforms[kLinux]!) {
      linuxOptions = await FirebaseWebOptions.forFlutterApp(
        flutterApp!,
        firebaseProjectId: selectedFirebaseProject.projectId,
        firebaseAccount: accountEmail,
        platform: kLinux,
        token: token,
      );
    }

    final writes = <FirebaseJsonWrites>[];

    if (androidOptions != null && applyGradlePlugins && flutterApp!.android) {
      final firebaseJsonWrite = await FirebaseAndroidGradlePlugins(
        flutterApp!,
        androidOptions,
        logger,
        androidServiceFilePath,
      ).apply(force: isCI || yes);

      writes.add(firebaseJsonWrite);
    }
    if (Platform.isMacOS) {
      if (iosOptions != null && flutterApp!.ios) {
        final firebaseJsonWrite = await FirebaseAppleSetup(
          platformOptions: iosOptions,
          flutterAppPath: flutterApp!.package.path,
          serviceFilePath: iosInputs!.serviceFilePath,
          logger: logger,
          buildConfiguration: iosInputs?.buildConfiguration,
          target: iosInputs?.target,
          platform: kIos,
          projectConfiguration: iosInputs!.projectConfiguration,
        ).apply();

        writes.add(firebaseJsonWrite);
      }

      if (macosOptions != null && flutterApp!.macos) {
        final firebaseJsonWrite = await FirebaseAppleSetup(
          platformOptions: macosOptions,
          flutterAppPath: flutterApp!.package.path,
          serviceFilePath: macosInputs!.serviceFilePath,
          logger: logger,
          buildConfiguration: macosInputs?.buildConfiguration,
          target: macosInputs?.target,
          platform: kMacos,
          projectConfiguration: macosInputs!.projectConfiguration,
        ).apply();

        writes.add(firebaseJsonWrite);
      }
    }

    await FirebaseConfigurationFile(
      outputFilePath,
      flutterApp!,
      androidOptions: androidOptions,
      iosOptions: iosOptions,
      macosOptions: macosOptions,
      webOptions: webOptions,
      windowsOptions: windowsOptions,
      linuxOptions: linuxOptions,
      force: isCI || yes,
      overwriteFirebaseOptions: overwriteFirebaseOptions,
    ).write();

    // "firebase.json" writes
    if (writes.isNotEmpty) {
      await writeToFirebaseJson(
        listOfWrites: writes,
        firebaseJsonPath: path.join(flutterApp!.package.path, 'firebase.json'),
      );
    }

    logger.stdout('');
    logger.stdout(
      logFirebaseConfigGenerated(outputFilePath),
    );
    logger.stdout('');
    logger.stdout(
      listAsPaddedTable(
        [
          [AnsiStyles.bold('Platform'), AnsiStyles.bold('Firebase App Id')],
          if (webOptions != null) [kWeb, webOptions.appId],
          if (androidOptions != null) [kAndroid, androidOptions.appId],
          if (iosOptions != null) [kIos, iosOptions.appId],
          if (macosOptions != null) [kMacos, macosOptions.appId],
          if (linuxOptions != null) [kLinux, linuxOptions.appId],
          if (windowsOptions != null) [kWindows, windowsOptions.appId],
        ],
        paddingSize: 2,
      ),
    );
    logger.stdout('');
    logger.stdout(
      logLearnMoreAboutCli,
    );
  }
}
