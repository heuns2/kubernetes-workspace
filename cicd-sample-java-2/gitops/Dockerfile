FROM openjdk:11-jdk-alpine
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar

CMD java -jar -Dmaven.test.skip=true -Xms256m -Xmx256m -XX:+UseG1GC -Dspring.profiles.active=default /app.jar  
