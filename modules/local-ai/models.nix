{ pkgs }:

# Immutable revisions plus the SHA-256 of the GGUF itself (Hugging Face LFS).
# These are ordinary fixed-output Nix derivations, not mutable model tags.
{
  eco = pkgs.fetchurl {
    name = "Qwen3.5-4B-Q4_K_M.gguf";
    url = "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/e87f176479d0855a907a41277aca2f8ee7a09523/Qwen3.5-4B-Q4_K_M.gguf";
    sha256 = "00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4";
  };
  ecoVision = pkgs.fetchurl {
    name = "Qwen3.5-4B-mmproj-F16.gguf";
    url = "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/e87f176479d0855a907a41277aca2f8ee7a09523/mmproj-F16.gguf";
    sha256 = "cd88edcf8d031894960bb0c9c5b9b7e1fea6ebee02b9f7ce925a00d12891f864";
  };
  performance = pkgs.fetchurl {
    name = "Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf";
    url = "https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/resolve/b17cb02dd882d5b6ab62fc777ad2995f19668350/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf";
    sha256 = "fadc3e5f8d42bf7e894a785b05082e47daee4df26680389817e2093056f088ad";
  };
}
