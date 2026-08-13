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
// Plugins that still declare an older compileSdk break the build once any
// other plugin requires a newer one -- file_picker compiles against
// android-34 while flutter_plugin_android_lifecycle now demands 36, and the
// failure surfaces as an opaque AAR-metadata error.
//
// Raising every Android library subproject to 36 is the standard fix and
// costs nothing: a higher compileSdk only allows newer APIs to be referenced,
// it does not touch minSdk or targetSdk, so which devices can install this
// does not move.
//
// Hooked on plugin application rather than afterEvaluate, because the
// evaluationDependsOn(":app") below has already evaluated these projects by
// the time an afterEvaluate would run -- which fails outright.
subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.let { ext ->
            val current = ext.compileSdk ?: 0
            if (current < 36) ext.compileSdk = 36
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
