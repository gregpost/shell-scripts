import torch

if torch.cuda.is_available():
    x = torch.rand(3, 3).cuda()
    print("Тензор на GPU:\n", x)
else:
    print("CUDA недоступна")
