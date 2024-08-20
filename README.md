# Containerfiles
Common Torizon Containerfiles for the community Container Images


# Usage:

If it is a multiarch image:

- Configure buildx, **if it is not configured yet**:
    ```
    docker buildx create --use
    ```

- Then, run the script:
    ```
    ./.scripts/pipeline.ps1 -PushToDockerhub $False -ImageNames <images_names_folder>
    ```