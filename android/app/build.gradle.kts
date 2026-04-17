import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { stream ->
        keystoreProperties.load(stream)
    }
}

val allowInsecureDebugSigning =
    project.findProperty("allowInsecureDebugSigning") == "true"

android {
    namespace = "com.severusbarber.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.severusbarber.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("production") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            if (!allowInsecureDebugSigning &&
                signingConfigs.findByName("production") == null
            ) {
                throw org.gradle.api.GradleException(
                    "Assinatura release obrigatoria. Configure android/key.properties " +
                        "com keystore de producao. " +
                        "Para testes locais apenas, use -PallowInsecureDebugSigning=true."
                )
            }

            signingConfig =
                when {
                    signingConfigs.findByName("production") != null ->
                        signingConfigs.getByName("production")
                    allowInsecureDebugSigning ->
                        signingConfigs.getByName("debug")
                    else ->
                        throw org.gradle.api.GradleException(
                            "Assinatura release ausente."
                        )
                }
        }
    }
}

flutter {
    source = "../.."
}
