# The official evennia/evennia image is amd64 only, so build our own for the Pi.
FROM python:3.13-slim
# Pinned: change the version on purpose, then: docker compose up -d --build
RUN pip install --no-cache-dir evennia==6.1.0
COPY entrypoint.sh /entrypoint.sh
# Strip Windows line endings in case the file was copied from a PC.
RUN sed -i 's/\r$//' /entrypoint.sh
WORKDIR /data
CMD ["sh", "/entrypoint.sh"]
