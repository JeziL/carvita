allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (path != ":app") {
        val isJniPlugin = name == "jni"
        afterEvaluate {
            if (plugins.hasPlugin("com.android.library")) {
                extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                    compileSdk = 36
                    if (isJniPlugin) {
                        defaultConfig {
                            externalNativeBuild {
                                cmake {
                                    arguments +=
                                        "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--build-id=none"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
