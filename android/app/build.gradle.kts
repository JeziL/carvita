import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}
val releaseSigningPropertyNames =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingReleaseSigningProperties =
    releaseSigningPropertyNames.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
val releaseStoreFilePath = keystoreProperties.getProperty("storeFile")
val releaseStoreFile =
    releaseStoreFilePath?.takeIf { it.isNotBlank() }?.let { project.file(it) }
val hasReleaseSigning =
    keystorePropertiesFile.exists() &&
        missingReleaseSigningProperties.isEmpty() &&
        releaseStoreFile?.isFile == true

android {
    namespace = "com.wangjinli.carvita"
    compileSdk = 36
    // ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.wangjinli.carvita"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

gradle.taskGraph.whenReady {
    val requestsReleaseArtifact =
        allTasks.any {
            it.project == project &&
                (it.name.contains("Release", ignoreCase = true) ||
                    it.name == "bundle" ||
                    it.name == "assemble")
        }
    if (requestsReleaseArtifact && !hasReleaseSigning) {
        val reason =
            when {
                !keystorePropertiesFile.exists() ->
                    "android/key.properties does not exist"
                missingReleaseSigningProperties.isNotEmpty() ->
                    "missing properties: ${missingReleaseSigningProperties.joinToString()}"
                else ->
                    "storeFile does not point to an existing keystore"
            }
        throw GradleException(
            "Release signing is not configured ($reason). " +
                "Debug builds use the standard Android debug key and do not require release secrets."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
