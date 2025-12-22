# Mejoras de Seguridad: Credenciales de Sysadmin en AWS Secrets Manager

## Problema Resuelto (Issue #6)

Anteriormente, el sistema creaba un usuario sysadmin de CKAN con credenciales predeterminadas hardcodeadas:
- Usuario: `ckan_admin`
- Contraseña: `testpass`
- Email: `ckan_admin@localhost`

**Esto representaba un grave riesgo de seguridad en ambientes de producción.**

## Solución Implementada

Las credenciales del usuario sysadmin ahora se almacenan de forma segura en **AWS Secrets Manager** y se configuran mediante variables de entorno en el archivo `.env`.

### Cambios Realizados

#### 1. Variables de Entorno en `.env`

Se agregaron tres nuevas variables en `.env.sample`:

```bash
# CKAN Sysadmin User Configuration
CKAN_SYSADMIN_USER=ckan_admin
CKAN_SYSADMIN_PASSWORD=ChangeThisSecurePassword456!
CKAN_SYSADMIN_EMAIL=admin@example.com
```

#### 2. Almacenamiento en AWS Secrets Manager

El script `scripts/tools/push-secrets.sh` ahora incluye estas credenciales en el secreto de AWS:

```json
{
  "ckan_sysadmin_user": "tu_usuario",
  "ckan_sysadmin_password": "contraseña_segura_generada",
  "ckan_sysadmin_email": "admin@tudominio.com"
}
```

La contraseña se genera automáticamente de forma segura si no se proporciona en el `.env`.

#### 3. Configuración de Terraform

El archivo `tf/modules/ecs-tasks/main.tf` ahora obtiene las credenciales desde AWS Secrets Manager en lugar de usar valores hardcodeados:

```terraform
secrets = [
  {
    name      = "CKAN_SYSADMIN_USER"
    valueFrom = "${var.app_secret_arn}:ckan_sysadmin_user::"
  },
  {
    name      = "CKAN_SYSADMIN_PASS"
    valueFrom = "${var.app_secret_arn}:ckan_sysadmin_password::"
  },
  {
    name      = "CKAN_SYSADMIN_MAIL"
    valueFrom = "${var.app_secret_arn}:ckan_sysadmin_email::"
  }
]
```

## Guía de Migración

### Para Nuevas Instalaciones

1. **Copiar el archivo de ejemplo**:
   ```bash
   cp .env.sample .env
   ```

2. **Configurar credenciales de sysadmin en `.env`**:
   ```bash
   CKAN_SYSADMIN_USER=admin_produccion
   CKAN_SYSADMIN_PASSWORD=UnaSuperContraseñaSegura123!@#
   CKAN_SYSADMIN_EMAIL=admin@tuorganizacion.com
   ```

3. **Subir secretos a AWS**:
   ```bash
   ./scripts/tools/push-secrets.sh
   ```

4. **Desplegar normalmente**:
   ```bash
   ./scripts/deploy.sh
   ```

### Para Instalaciones Existentes

Si ya tienes una instalación desplegada con las credenciales antiguas:

1. **Actualizar tu archivo `.env`** con las nuevas variables:
   ```bash
   echo "CKAN_SYSADMIN_USER=nuevo_admin" >> .env
   echo "CKAN_SYSADMIN_PASSWORD=NuevaContraseñaSegura456!" >> .env
   echo "CKAN_SYSADMIN_EMAIL=admin@tudominio.com" >> .env
   ```

2. **Actualizar los secretos en AWS**:
   ```bash
   ./scripts/tools/push-secrets.sh --update
   ```

3. **Redesplegar la aplicación**:
   ```bash
   ./scripts/redeploy.sh
   ```

   O forzar una nueva tarea ECS para que tome los nuevos secretos:
   ```bash
   aws ecs update-service \
     --cluster ckan-cluster-${ENVIRONMENT} \
     --service ckan-service-${ENVIRONMENT} \
     --force-new-deployment \
     --region ${AWS_REGION}
   ```

4. **Opcional: Eliminar el usuario antiguo** (si existe):
   ```bash
   # Conectarse al contenedor
   ./scripts/tools/ecs-exec.sh
   
   # Dentro del contenedor
   ckan user remove ckan_admin  # Solo si usabas el usuario por defecto
   ```

## Recomendaciones de Seguridad

### Contraseñas Seguras

- **Longitud mínima**: 16 caracteres
- **Complejidad**: Combinar mayúsculas, minúsculas, números y caracteres especiales
- **Generación**: Usar generadores de contraseñas seguros
  ```bash
  # Generar una contraseña segura
  openssl rand -base64 24
  ```

### Rotación de Credenciales

Para rotar la contraseña del sysadmin:

1. Actualizar el valor en `.env`
2. Ejecutar `./scripts/tools/push-secrets.sh --update`
3. Redesplegar o reiniciar el servicio ECS
4. Cambiar la contraseña también desde la interfaz de CKAN si es necesario

### Auditoría

Monitorear el acceso al secreto en AWS Secrets Manager:
- Habilitar CloudTrail para registrar accesos
- Configurar alertas para accesos inusuales
- Revisar periódicamente los logs de acceso

## Verificación

Para verificar que las credenciales se están cargando correctamente:

```bash
# Conectarse al contenedor
./scripts/tools/ecs-exec.sh

# Verificar variables de entorno (NO mostrar valores completos en producción)
echo "User: $CKAN_SYSADMIN_USER"
echo "Email: $CKAN_SYSADMIN_MAIL"
# NO ejecutar: echo $CKAN_SYSADMIN_PASS

# Verificar que el usuario existe en CKAN
ckan user show $CKAN_SYSADMIN_USER
```

## Beneficios

✅ **Seguridad mejorada**: Las credenciales nunca están en el código fuente  
✅ **Gestión centralizada**: Un solo lugar para administrar secretos  
✅ **Rotación simplificada**: Cambiar credenciales sin modificar código  
✅ **Auditoría**: AWS CloudTrail registra todos los accesos a secretos  
✅ **Encriptación**: Secretos encriptados en reposo y en tránsito  
✅ **Separación de entornos**: Credenciales diferentes por ambiente (dev/staging/prod)  

## Soporte

Si encuentras problemas con esta implementación, por favor abre un issue en el repositorio.
