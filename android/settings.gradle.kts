pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val localPropertiesFile = file("local.properties")
            if (localPropertiesFile.exists()) {
                localPropertiesFile.inputStream().use { properties.load(it) }
            }

            val candidatePaths =
                listOfNotNull(
                    properties.getProperty("flutter.sdk"),
                    System.getenv("FLUTTER_ROOT"),
                    System.getenv("FLUTTER_HOME"),
                )

            val resolvedFlutterSdkPath =
                candidatePaths.firstOrNull { candidatePath ->
                    file("$candidatePath/packages/flutter_tools/gradle").exists()
                }

            require(resolvedFlutterSdkPath != null) {
                "Unable to find a valid Flutter SDK path. Set flutter.sdk in android/local.properties or FLUTTER_ROOT."
            }

            resolvedFlutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.4") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
