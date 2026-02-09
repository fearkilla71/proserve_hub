import com.android.build.gradle.LibraryExtension

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

// Workaround for older/discontinued plugins that don't declare `android.namespace`,
// which is required by newer Android Gradle Plugin versions.
subprojects {
    if (name == "uni_links") {
        plugins.withId("com.android.library") {
            extensions.configure(LibraryExtension::class.java) {
                namespace = "com.proservehub.uni_links"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
