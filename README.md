# to-do-list-api

API para gestionar tareas pendientes, con las tareas guardadas en RDS (PostgreSQL). La infraestructura se crea con Terraform, el ciclo de vida se automatiza con GitHub Actions y se monitorea con CloudWatch.

Práctica 4 de Desarrollo en la Nube (ITESO).

## Endpoints

| Endpoint | Descripción |
|---|---|
| `GET /tasks` | Regresa la lista de tareas |
| `POST /tasks` | Crea una tarea nueva (`{"title": "...", "done": false}`) |
| `GET /version` | Regresa la versión desplegada (variable de ambiente `APP_VERSION`) |
| `GET /health` | Revisa la conexión a la base de datos (OK/FAIL), la versión y un timestamp |

```bash
curl -X POST http://<ip-de-la-ec2>:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "estudiar para el examen de desarrollo en la nube", "done": false}'

curl http://<ip-de-la-ec2>:8000/tasks
```

## Estructura

```
src/                 app en Flask (main.py) y dependencias
tests/               pruebas unitarias con pytest
terraform/           EC2, Security Groups, Key Pair, RDS, secret y user_data
alerting/            alarmas, dashboard y script que los crea en CloudWatch
.github/workflows/   provision, destroy, ci, release, deploy y health-check
```

## Arquitectura

- **EC2** (Ubuntu, t3.micro): al arrancar, `user_data` clona este repo, instala dependencias y levanta la app con systemd en el puerto 8000.
- **RDS** (PostgreSQL, db.t3.micro): guarda las tareas. Solo acepta conexiones desde la EC2.
- **Secrets Manager**: el secret `todo/db-credentials` tiene las credenciales de RDS. La app lo lee en tiempo de ejecución usando `LabInstanceProfile`.
- **S3**: el bucket `todo-list-tfstate-dubu2500` guarda el tfstate de Terraform.
- **CloudWatch + SNS**: 3 métricas, 3 alarmas que avisan por correo y un dashboard.

## Configuración

### Llave SSH

```bash
ssh-keygen -t ed25519 -f todo-key -N ""
```

`todo-key.pub` es la llave pública y `todo-key` la privada. Ninguna se sube al repo.

### GitHub Secrets

En *Settings → Secrets and variables → Actions*:

| Secret | Valor |
|---|---|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | Credenciales del Learner Lab (*AWS Details → AWS CLI*). Cambian en cada sesión |
| `SSH_PUBLIC_KEY` | Contenido de `todo-key.pub` |
| `EC2_SSH_KEY` | Contenido de `todo-key` |
| `EC2_HOST` | IP pública de la EC2 (la muestra el workflow de provisión) |
| `ALERT_EMAIL` | Correo que recibe las alarmas |
| `RELEASE_TOKEN` | Token personal fine-grained con permiso *Contents: Read and write* en este repo |

## Crear la infraestructura

1. Actualiza los 3 secrets de AWS con las credenciales del lab.
2. En *Actions → Provision infrastructure → Run workflow*.
   - Crea el bucket del tfstate si no existe.
   - Corre `terraform init`, `plan` y `apply`.
   - Crea el tópico de SNS, las alarmas y el dashboard.
3. Copia la IP que aparece en el resumen del workflow al secret `EC2_HOST`.
4. Confirma la suscripción de SNS en el correo que llega de AWS.
5. Espera unos minutos a que RDS y la app arranquen y prueba `GET /health`.

## Destruir la infraestructura

En *Actions → Destroy infrastructure → Run workflow*. Corre `terraform destroy` y borra la EC2, la RDS, el secret, los Security Groups y el Key Pair. El bucket del tfstate no se borra.

## CI/CD

- **CI** (`ci.yml`): al abrir un Pull Request a `main` corre las pruebas. `main` está protegida, así que solo se puede integrar por PR y con el check `tests` en verde.
- **Release** (`release.yml`): al empujar una etiqueta `v#.#.#` crea un release con el repo comprimido en zip.
- **Deploy** (`deploy.yml`): al publicarse un release, descarga el zip en la EC2 por SSH, pone `APP_VERSION` con la etiqueta, reinicia la app y revisa `GET /version`.
- **Health check** (`health-check.yml`): cada 5 minutos revisa `GET /health` y falla si la base de datos no responde OK.

```bash
git tag v1.0.1
git push origin v1.0.1
```

## Observabilidad

| Métrica | Origen | Alarma |
|---|---|---|
| `AWS/EC2 CPUUtilization` | Nativa de AWS | `todo-ec2-cpu-alta`: > 80 % durante 10 min |
| `TodoListApi DBErrors` | `put_metric_data` cuando falla leer o escribir en RDS | `todo-db-errores`: ≥ 1 error en 1 min |
| `TodoListApi TasksCreated` | `put_metric_data` cada vez que se crea una tarea | `todo-tareas-creadas-pico`: > 50 tareas en 5 min |

La configuración está en `alerting/alarms.json` y `alerting/cloudwatch-dashboard.json`. Para probar la alarma de errores, detén la instancia de RDS y haz peticiones a `/tasks` o `/health`.

## Correr localmente

Las pruebas no necesitan AWS:

```bash
pip install -r tests/requirements.txt
pytest tests -v
```

Para correr la app se necesitan credenciales de AWS y un secret con las credenciales de una base de datos PostgreSQL:

```bash
pip install -r src/requirements.txt
SECRET_NAME=todo/db-credentials AWS_REGION=us-east-1 python src/main.py
```
