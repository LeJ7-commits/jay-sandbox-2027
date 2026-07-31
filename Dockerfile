FROM apache/airflow:2.10.5-python3.12

USER root
RUN apt-get update && apt-get install -y --no-install-recommends python3-venv git \
    && rm -rf /var/lib/apt/lists/*
USER airflow

RUN python3 -m venv /home/airflow/.venvs/meltano
COPY requirements.txt /requirements.txt
RUN /home/airflow/.venvs/meltano/bin/pip install --no-cache-dir -r /requirements.txt

COPY --chown=airflow:0 dags /opt/airflow/dags
COPY --chown=airflow:0 meltano_project /opt/airflow/meltano_project
