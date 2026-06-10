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

// 🚀 O GATILHO CIRÚRGICO: Injeta o SDK 35 ANTES do Flutter trancar o arquivo, MAS poupa o installed_apps!
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

// O Flutter tranca a leitura nesta linha aqui embaixo:
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}