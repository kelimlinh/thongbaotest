import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.terrarium"
    compileSdk = flutter.compileSdkVersion.toInt()

    defaultConfig {
        applicationId = "com.example.terrarium"
        minSdk = flutter.minSdkVersion.toInt()
        targetSdk = flutter.targetSdkVersion.toInt()

        // Đọc versionCode và versionName từ local.properties
        val flutterProperties = Properties().apply {
            load(gradle.rootProject.file("local.properties").inputStream())
        }

        versionCode = flutterProperties["flutter.versionCode"].toString().toInt()
        versionName = flutterProperties["flutter.versionName"].toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-database")
    implementation("com.google.firebase:firebase-auth")
}
