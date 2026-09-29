allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ─── Workaround for legacy Android library plugins ───
// Fixes two issues with on_audio_query_android 1.1.0 (and similar old plugins)
// when building with AGP 8.6+ and Kotlin 2.1.0+:
//   1. Missing 'namespace' (required by AGP 8+)
//   2. JVM target mismatch between javac (1.8) and kotlinc (21)
subprojects {
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByName("android")
            as? com.android.build.api.dsl.LibraryExtension
        if (androidExt != null) {
            // Fix 1: inject namespace from AndroidManifest.xml if missing
            if (androidExt.namespace == null) {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val manifestText = manifestFile.readText()
                    val match = Regex("""package="([^"]+)"""").find(manifestText)
                    if (match != null) {
                        androidExt.namespace = match.groupValues[1]
                    }
                }
            }

            // Fix 2: align Java compile options to avoid JVM-target mismatch
            androidExt.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }

        // Fix 3: ensure compileSdk is at least 34 for legacy libraries (e.g. on_audio_query_android) using finalizeDsl
        val androidComponents = extensions.findByType(com.android.build.api.variant.AndroidComponentsExtension::class.java)
        androidComponents?.finalizeDsl { extension ->
            (extension as? com.android.build.api.dsl.LibraryExtension)?.let { libExt ->
                if ((libExt.compileSdk ?: 0) < 34) {
                    libExt.compileSdk = 34
                }
            }
        }

        // Fix 2 (Kotlin side): align Kotlin JVM target with javac target dynamically
        afterEvaluate {
            val updatedAndroidExt = extensions.findByName("android")
                as? com.android.build.api.dsl.LibraryExtension
            val targetCompat = updatedAndroidExt?.compileOptions?.targetCompatibility
            if (targetCompat != null) {
                tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                    compilerOptions {
                        jvmTarget.set(
                            org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(targetCompat.toString())
                        )
                    }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
