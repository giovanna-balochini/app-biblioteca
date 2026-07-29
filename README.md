# app-biblioteca

Projeto de biblioteca com Flutter (frontend) e Spring Boot (backend). Em desenvolvimento.

## Estrutura

- `frontend/` Flutter
- `backend/bibliotecabackend/` Spring Boot

## Backend (Spring Boot)

Pré-requisito: MySQL rodando localmente.

Config local (não versionada):

1. Crie/edite `backend/bibliotecabackend/src/main/resources/application-local.properties`
2. Configure:

```properties
spring.datasource.username=root
spring.datasource.password=SUA_SENHA_AQUI
```

Subir o backend (na pasta `backend/bibliotecabackend`):

```bash
./mvnw spring-boot:run
```

API (padrão): `http://localhost:8080`

## Frontend (Flutter)

Na pasta `frontend/`:

```bash
flutter pub get
flutter run
```
