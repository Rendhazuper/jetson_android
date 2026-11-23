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
subprojects {
    project.evaluationDependsOn(":app")
}

// onnxruntime 1.4.1 (plugin pub.dev, versi terbaru) dikunci compileSdk 33,
// sedangkan dependency AndroidX-nya butuh 34+ (checkDebugAarMetadata gagal).
// Naikkan compileSdk-nya ke 36, sama dengan flutter.compileSdkVersion.
subprojects {
    plugins.withId("com.android.library") {
        if (project.name == "onnxruntime") {
            extensions
                .getByType<com.android.build.api.variant.LibraryAndroidComponentsExtension>()
                .finalizeDsl { ext ->
                    (ext as com.android.build.api.dsl.LibraryExtension).compileSdk = 36
                }
        }
    }
}

// camera-core 1.6.0 (dipakai camera_android_camerax) mereferensi
// CallbackToFutureAdapter, tetapi POM-nya menandai concurrent-futures sebagai
// `runtime`, sehingga tidak masuk compile classpath dan javac gagal dengan
// "class file for androidx.concurrent.futures.CallbackToFutureAdapter not found".
subprojects {
    plugins.withId("com.android.library") {
        if (project.name == "camera_android_camerax") {
            dependencies {
                add("implementation", "androidx.concurrent:concurrent-futures:1.1.0")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
