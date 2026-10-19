group = "dev.stratum.stratum_ui"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "dev.stratum.stratum_ui"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isReturnDefaultValues = true
            all { it.useJUnitPlatform() }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // 1.16.0 adds JavaScriptReplyProxy.executeJavaScript; Gradle resolves
    // webview_flutter_android 4.14.1's 1.15.0 up to it.
    implementation("androidx.webkit:webkit:1.16.0")
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    // Mockito 5's inline mock maker mocks the static WebViewCompat,
    // WebViewFeature, and WebViewFlutterAndroidExternalApi calls.
    testImplementation("org.mockito:mockito-core:5.0.0")
}
