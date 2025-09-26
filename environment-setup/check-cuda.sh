#!/bin/bash
python3 -c "import torch; print('PyTorch version:', torch.__version__); print('CUDA доступен:', torch.cuda.is_available()); print('Имя GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'Нет CUDA')"
