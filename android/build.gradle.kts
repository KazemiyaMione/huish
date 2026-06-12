// 设置国内镜像源
buildscript {
    repositories {
        // 阿里云镜像 - 注意使用双引号
        google()
        mavenCentral()
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        // 腾讯云镜像（备选）
        // maven { url = uri("https://mirrors.cloud.tencent.com/nexus/repository/maven-public/") }

    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // 国内镜像源（加速依赖下载，fallback）
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
    }
}

// 自定义构建目录到项目根目录的build文件夹
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
    // 确保子项目依赖正确的仓库
    project.repositories.addAll(rootProject.repositories)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}