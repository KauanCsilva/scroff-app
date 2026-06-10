allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newBuildDir: Directory = rootProject.layout.buildDirectory.dir(project.name).get()
    project.layout.buildDirectory.value(newBuildDir)
}

// Forces compileSdk 35 on all subprojects except installed_apps
subprojects {
    afterEvaluate {
        if (project.name != "installed_apps") {
            if (extensions.findByName("android") != null) {
                val androidExt = extensions.getByName("android") as com.android.build.gradle.BaseExtension
                androidExt.compileSdkVersion(35)
            }
        }
    }
}

// Forces androidx.core to 1.15.0 across all subprojects
subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.15.0")
            force("androidx.core:core-ktx:1.15.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}