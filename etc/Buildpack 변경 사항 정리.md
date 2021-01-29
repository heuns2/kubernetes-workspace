
# Buildpack 변경 사항 정리

## 1. Buildpack 내부 설정 일부설명 & 변경 사항
- 실제 buildpack의 동작 소스 코드는 /lib 디렉토리에 들어가있으며 lib은 bin 디렉토리에 의해 실행, config 디렉토리에 의해 설정되게 되게 됩니다.
- 이 때 여러 cache에 대한 다운로드는 아래 파일에서 이루어지게 됩니다. 아래 파일을 요약하게 되면 config 디렉토리에서 repository, platform, architecture 등을 받고 /index.yml을 호출하게 됩니다.
- cloud foundry에서 사용하는 index.yml에 대한 링크는 다음과 같습니다. [https://java-buildpack.cloudfoundry.org/](https://java-buildpack.cloudfoundry.org/) << java-buildpack은 해당 디렉토리에서 index.yml을 읽고 index.yml를 통해 tar, jar 등 실행 파일을 다운로드 합니다. 해당 문서로는 oracle-jdk tar 파일을 가져오게 됩니다.

```
# 일부 발췌
$ cat lib/java_buildpack/repository/repository_index.rb

      def initialize(repository_root)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger RepositoryIndex

        @default_repository_root = JavaBuildpack::Util::ConfigurationUtils.load('repository')['default_repository_root']
                                                                          .chomp('/')

        cache.get("#{canonical repository_root}#{INDEX_PATH}") do |file|
          @index = YAML.load_file(file)
          @logger.debug { @index }
        end
      end

      # Finds a version of the file matching the given, possibly wildcarded, version.
      #
      # @param [String] version the possibly wildcarded version to find
      # @return [TokenizedVersion] the version of the file found
      # @return [String] the URI of the file found
      def find_item(version)
        found_version = VersionResolver.resolve(version, @index.keys)
        raise "No version resolvable for '#{version}' in #{@index.keys.join(', ')}" if found_version.nil?

        uri = @index[found_version.to_s]
        [found_version, uri]
      end
      
      private
      INDEX_PATH = '/index.yml'
      private_constant :INDEX_PAT
```

## 1.1. 소스 코드 변경 부분

### 1.1.1. config/components.yml(기존과 동일)
- config/components.yml 파일에서 open_jre를 주석 oracel_jre를 주석해제 합니다.

```
#  - "JavaBuildpack::Jre::OpenJdkJRE"
   - "JavaBuildpack::Jre::OracleJRE"
```

### 1.1.2. cat config/oracle_jre.yml(기존과 동일)
- 사용할 jre 버전과 repository_root를 지정합니다.

```
jre:
  version: 1.8.0_202
  repository_root: http://localhost:8080/
```

## 2. Apache, Hosts 설정

### 2.1. hosts
- IP가 아닌 hostname으로 보이기 위해 /etc/hosts에 ip/hostname을 추가합니다.

### 2.2. Apache 설정
#### 2.2.1. apache config 설정
- 현재 <VirtualHost *:8080> 8080 PORT로 들어오는 요청에 대해서는 DocumentRoot /home/ubuntu/buildpack/가 설정되어 있습니다. 즉 {IP OR DOMAIN}:8080으로 요청을 하게 되면 /home/ubuntu/buildpack/ 안에 내용을 읽을수 있습니다.

- /home/ubuntu/buildpack/ 디렉토리안에는 Buildpack 패키징 시 사용 될 index.yml와 JDK 또는 JRE가 있습니다.
- 이 때 index.yml은 Buildpack 소스 코드에서 사용할 jre의 버전과 다운로드 할  JRE의 명과 일치 해야 합니다. ( JDK 아님)
- index.yml 확인 Link: [http://x.xxx.xxx.xxx:8080/index.yml](http://x.xxx.xxx.xx:8080/index.yml)

```
$ ls -al
-rw-r--r--  1 ubuntu ubuntu        88 Jun  4 15:10 index.yml
-rw-rw-r--  1 ubuntu ubuntu 88983969 Jun  4 14:19 jre-8u202-linux-x64.tar.gz

$ cat index.yml
---
1.8.0_202: http://orecle-java-buildpack.xxx.xx.xx:8080/jre-8u202-linux-x64.tar.gz
```




## 3. Gemfile Build & PAS Upload Buildpack

- Java Offline Buildpack Dependency Download & Source Code Build

```
$ bundle install
$ bundle exec rake clean package OFFLINE=true PINNED=true
...
Creating build/java-buildpack-offline-cfd6b17.zip
```

- PAS Upload Buldpack

```
$ cf create-buildpack oracle_java_buildpack  oracle-java-buildpack-offline-cflinuxfs3-v4.29.1.zip  15 --enable
```

## 4. ETC
- Buildpack 버전이 올라가게 되면 Dependency 문제로 Ruby 버전도 올라가야 할 필요가 있을 수 있습니다. 만약 geminstall 중 dependency에서 에러가 발생 하였을 경우 아래 명령을 통해 Ruby를 설치 & 버전 변경을 할 수 있습니다.
- ruby에서 java pom.xml 같은 역활을 하는 파일은 Gemfile입니다. 해당 파일에서 모든 Dependency를 확인 할 수 있습니다.

```
$ sudo apt-get update

# 신규 버전 or 다음 버전의 ruby 설치
$ sudo apt-get install ruby{특정 버전} -y

$ ruby-switch --list
ruby2.5
ruby2.6

$ ruby-switch --set ruby2.6

$ ruby -v
ruby 2.6.5p114 (2019-10-01 revision 67812) [x86_64-linux-gnu]

$ gem install bundler
``` 

## 5. 결과

```
 cf push test -p performance-0.0.1-SNAPSHOT.jar -b oracle_java_buildpack
Pushing app test to org patch / space common as admin...
Getting app info...
Creating app with these attributes...
+ name:         test
  path:         /PCF/FOUNDATION/patch/sample-app/springboot-performance-simulator-master/target/performance-0.0.1-SNAPSHOT.jar
  buildpacks:
+   oracle_java_buildpack
  routes:
+   test.apps.patch.xxx.xxx.xx

Creating app test...
Mapping routes...
Comparing local files to remote cache...
Packaging files to upload...
Uploading files...
 347.84 KiB / 347.84 KiB [==============================================================================================================================] 100.00% 1s

Waiting for API to complete processing files...

Staging app and tracing logs...
   Downloading oracle_java_buildpack...
   Downloaded oracle_java_buildpack
   Cell cc2739dd-2ef1-495b-b29a-e4e27844dac9 creating container for instance dba8342a-1f90-4876-8ed8-1e0a158f0445
   Cell cc2739dd-2ef1-495b-b29a-e4e27844dac9 successfully created container for instance dba8342a-1f90-4876-8ed8-1e0a158f0445
   Downloading app package...
   Downloaded app package (17.2M)
   -----> Java Buildpack v4.29.1 (offline)
   -----> Downloading Jvmkill Agent 1.16.0_RELEASE from https://java-buildpack.cloudfoundry.org/jvmkill/bionic/x86_64/jvmkill-1.16.0-RELEASE.so (found in cache)
   -----> Downloading Oracle JRE 1.8.0_202 from http://orecle-java-buildpack.xxx.xxx.xx:8080/jdk-8u202-linux-x64.tar.gz (found in cache)
          Expanding Oracle JRE to .java-buildpack/oracle_jre (3.0s)

```
