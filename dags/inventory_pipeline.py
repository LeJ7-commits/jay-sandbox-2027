from __future__ import annotations
import logging
from datetime import datetime, timedelta
from airflow.decorators import dag, task
from airflow.operators.bash import BashOperator

log = logging.getLogger(__name__)
MELTANO_PROJECT = "/opt/airflow/meltano_project"
MELTANO_BIN = "/home/airflow/.venvs/meltano/bin/meltano"
default_args = {"retries": 2, "retry_delay": timedelta(minutes=2)}

def on_task_failure(context):
    ti = context["task_instance"]
    log.error("ALERT: %s in %s failed", ti.task_id, ti.dag_id)

@dag(dag_id="inventory_pipeline", schedule="@daily", start_date=datetime(2026, 7, 1),
     catchup=False, default_args=default_args, tags=["inventory"])
def inventory_pipeline():
    extract_load = BashOperator(
        task_id="meltano_extract_load",
        bash_command=f"cd {MELTANO_PROJECT} && {MELTANO_BIN} run tap-csv target-postgres",
        on_failure_callback=on_task_failure,
    )
    transform = BashOperator(
        task_id="dbt_build",
        bash_command=f"cd {MELTANO_PROJECT} && {MELTANO_BIN} invoke dbt-postgres:build",
        on_failure_callback=on_task_failure,
    )

    @task(on_failure_callback=on_task_failure)
    def notify():
        log.info("inventory_pipeline finished")

    extract_load >> transform >> notify()

inventory_pipeline()