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
    plugins.withId("com.android.library") {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                if (getNamespace.invoke(android) == null) {
                    val fallback = "com.example.fallback.${project.name.replace("-", "_").replace(".", "_")}"
                    setNamespace.invoke(android, fallback)
                }
            } catch (e: Exception) {
                // ignore if reflection fails
            }
            try {
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                val javaVersion8 = org.gradle.api.JavaVersion.VERSION_1_8
                compileOptions.javaClass.getMethod("setSourceCompatibility", org.gradle.api.JavaVersion::class.java).invoke(compileOptions, javaVersion8)
                compileOptions.javaClass.getMethod("setTargetCompatibility", org.gradle.api.JavaVersion::class.java).invoke(compileOptions, javaVersion8)
            } catch (e: Exception) {
                // ignore if reflection fails
            }
        }
        // Remove package="..." from AndroidManifest.xml to prevent processReleaseManifest errors in AGP 8+
        val manifestFile = file("src/main/AndroidManifest.xml")
        if (manifestFile.exists()) {
            try {
                var content = manifestFile.readText()
                if (content.contains("package=")) {
                    content = content.replace(Regex("""package="[^"]*""""), "")
                    manifestFile.writeText(content)
                }
            } catch (e: Exception) {
                // ignore
            }
        }
    }
}

subprojects {
    tasks.configureEach {
        if (this.javaClass.name.contains("KotlinCompile") || this.name.contains("Kotlin")) {
            try {
                val kotlinOptions = this.javaClass.getMethod("getKotlinOptions").invoke(this)
                val android = project.extensions.findByName("android")
                val jvmTargetVal = if (android != null) {
                    val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                    val targetCompat = compileOptions.javaClass.getMethod("getTargetCompatibility").invoke(compileOptions).toString()
                    when {
                        targetCompat.contains("17") || targetCompat == "17" -> "17"
                        targetCompat.contains("21") || targetCompat == "21" -> "21"
                        targetCompat.contains("11") || targetCompat == "11" -> "11"
                        else -> "1.8"
                    }
                } else {
                    "1.8"
                }
                kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java).invoke(kotlinOptions, jvmTargetVal)
            } catch (e: Exception) {
                // ignore
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
