import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de release: senha e caminho do keystore vivem em
// android/key.properties, que fica FORA do git (ver android/.gitignore).
// Sem esse arquivo o release cai na chave de debug, e o app assinado assim
// não atualiza por cima do que foi assinado com a chave de verdade.
val chaves = Properties().apply {
    val arquivo = rootProject.file("key.properties")
    if (arquivo.exists()) arquivo.inputStream().use { load(it) }
}
val temChave = chaves.getProperty("storeFile") != null

android {
    namespace = "com.kodem.mago_a_ascensao"
    // Plugins (printing) exigem 36; ver bloco subprojects no build.gradle.kts raiz.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Duas versões instaláveis lado a lado no mesmo aparelho:
    //  * estavel — o app publicado, id com.kodem.mago_a_ascensao
    //  * beta    — o mesmo app com `.beta` no id e outro nome na gaveta,
    //              para experimentar sem derrubar a ficha que está em uso.
    //              (o AGP não aceita flavor começando com "test")
    // Ambas assinadas com a MESMA chave, então cada uma atualiza por cima
    // de si mesma sem desinstalar.
    // resValue (o nome do app por canal) vem desligado por padrão no AGP novo
    buildFeatures {
        resValues = true
    }

    flavorDimensions += "canal"

    productFlavors {
        create("estavel") {
            dimension = "canal"
            resValue("string", "app_name", "Mago: A Ascensão")
        }
        create("beta") {
            dimension = "canal"
            applicationIdSuffix = ".beta"
            versionNameSuffix = "-beta"
            resValue("string", "app_name", "Mago (teste)")
        }
    }

    defaultConfig {
        applicationId = "com.kodem.mago_a_ascensao"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // versionCode e versionName saem do `version:` do pubspec.yaml
        // (ex.: 1.1.0+2 -> versionName 1.1.0, versionCode 2)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (temChave) {
            create("release") {
                storeFile = rootProject.file(chaves.getProperty("storeFile"))
                storePassword = chaves.getProperty("storePassword")
                keyAlias = chaves.getProperty("keyAlias")
                keyPassword = chaves.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (temChave) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
