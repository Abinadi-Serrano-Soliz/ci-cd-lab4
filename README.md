# Proyecto final implementacion ci-cd

**Grupo 12**

**Integrantes:**
- Camargo Soleto Gustavo Sebastián 
- Saavedra Gómez Henry
- Serrano Soliz Abinadi
- Villca Quiroga Ronald Nelson

---

## Automatización de Despliegues para Aplicación Spring Boot

Este repositorio contiene la implementación completa de un pipeline de Integración Continua (CI) y Despliegue Continuo (CD) para una aplicación backend basada en Spring Boot (Java 21). El objetivo del proyecto es garantizar entregas rápidas, seguras y sin tiempo de inactividad utilizando una arquitectura Blue-Green Deployment.

## 1. Información General y Arquitectura

El proyecto define un flujo automatizado de CI/CD que permite a los desarrolladores enfocarse en el código, mientras que las herramientas subyacentes se encargan de las pruebas, el empaquetado y el despliegue de manera consistente.

**Tecnologías Clave Utilizadas:**
- **Control de Versiones:** Git y GitHub.
- **CI/CD Pipeline:** GitHub Actions.
- **Backend:** Java 21, Spring Boot.
- **Construcción y Dependencias:** Maven.
- **Testing y Calidad:** JUnit y JaCoCo (Análisis de Cobertura).
- **Despliegue y Enrutamiento:** Bash Scripts, Nginx (como balanceador de carga), y Máquinas Virtuales Ubuntu locales.

## 2. Estrategia de Branching y Tagging

El flujo de trabajo está diseñado para mantener la estabilidad del código en producción y permitir el desarrollo iterativo.

- **Ramas de Desarrollo (`feature/*`):** Todo el desarrollo de nuevas características o corrección de bugs se realiza en ramas con el prefijo `feature/`.
- **Integración (`main`):** La rama `main` contiene el código estable listo para producción. La integración de código hacia `main` se realiza exclusivamente mediante **Pull Requests (PR)**, lo que asegura que el código pase las pruebas antes de ser fusionado.
- **Semantic Versioning y Tags:** Se utilizan etiquetas (Tags) de Git bajo el formato de versionamiento semántico (Ej. `v1.0.0`, `v1.2.3`). Al crear un tag que empiece con `v`, se dispara automáticamente el proceso de empaquetado y liberación (Release).

## 3. Pipeline de Integración Continua (CI)

La Integración Continua está gestionada por GitHub Actions a través del archivo `maven.yml`. Este pipeline se ejecuta ante cada *push* a `main` y `feature/*`, o en la creación de *Pull Requests*.

El flujo del CI es el siguiente:
1. **Checkout:** Se descarga el código fuente del repositorio.
2. **Setup JDK:** Se configura el entorno de construcción con Java (distribución Temurin).
3. **Build:** Maven compila el proyecto sin ejecutar pruebas (`mvn package -DskipTests`) para acelerar la validación de compilación.
4. **Pruebas Unitarias:** Se ejecutan las pruebas del proyecto (`mvn test`) usando JUnit.
5. **Análisis de Cobertura:** Se genera el reporte de cobertura de código utilizando el plugin de **JaCoCo** (`mvn test jacoco:report`).
6. **Empaquetado y Artefactos:** Los archivos generados (`.jar`, reportes de pruebas y de cobertura) se publican como artefactos de GitHub Actions para su posterior uso o revisión.

Además, el archivo `release.yml` automatiza la publicación en GitHub Releases. Cuando se hace un *push* de un Tag (ej. `v1.0.0`), este pipeline compila el proyecto, extrae el `.jar` y crea un **GitHub Release** vinculado a ese tag con el binario listo para descargar.

## 4. Estrategia de Despliegue Continuo (CD)

Para el Despliegue Continuo, se ha elegido una estrategia **Blue-Green Deployment**. Esta estrategia permite minimizar el *downtime* (tiempo de inactividad) a cero y reduce drásticamente los riesgos al implementar nuevas versiones.

**¿Por qué Blue-Green?** Nginx actúa como balanceador de carga local, dirigiendo todo el tráfico al entorno activo (ej. Blue). Mientras tanto, la nueva versión se despliega en el entorno inactivo (ej. Green) sin afectar a los usuarios. Solo cuando la nueva versión es estable, Nginx cambia el tráfico.

**Automatización con Scripts Bash:**
- **`deploy-blue-green.sh`:** Este script orquesta todo el despliegue. Detecta cuál es el entorno activo actual leyendo el archivo `active-environment`. Luego, determina el entorno destino (Target), detiene cualquier instancia previa allí, realiza un backup del `.jar` anterior, copia el nuevo `.jar` e inicia el servicio (puerto `8080` para Blue y `8081` para Green).
- **`deploy.sh`:** (Script alternativo) Permite realizar un despliegue directo estándar con parada de servicio temporal y creación de backups automáticos.

## 5. Validaciones y Rollback

Un despliegue no se considera exitoso solo por iniciar la aplicación; es necesario validar que esté funcionando correctamente antes de enviarle tráfico real.

**Health Checks y Pruebas End-to-End (E2E):**
Dentro del script `deploy-blue-green.sh`, tras levantar la nueva instancia en el entorno inactivo, se realiza un proceso de monitoreo automático (Health Check). El script utiliza `curl` para consultar el endpoint `http://localhost:<TARGET_PORT>/health` periódicamente hasta 20 veces.
- Si el endpoint responde correctamente, la instancia se considera **Healthy** (saludable) y está lista.
- Una vez validado, se procede a cambiar el tráfico en Nginx mediante la función `switch_traffic` hacia el nuevo entorno.

**Procedimiento de Rollback:**
Si la nueva versión falla (ej. el Health Check no responde a tiempo, la base de datos no conecta o la aplicación se cae al iniciar):
1. **Detección del Fallo:** El script detecta que la variable `$HEALTHY` no es verdadera.
2. **Aislamiento:** Automáticamente detiene la instancia fallida en el entorno inactivo para liberar recursos y detener errores.
3. **Mantenimiento del Servicio:** El script falla intencionalmente (`exit 1`) **antes** de llegar a la instrucción que reconfigura Nginx (`switch_traffic`).
4. **Recuperación (Rollback):** Debido a que el tráfico en Nginx jamás fue modificado, los usuarios continúan interactuando con la versión estable anterior que sigue ejecutándose intacta en el entorno activo. Esto resulta en un rollback instantáneo y automático sin intervención manual ni percepción de falla por parte del usuario final.
