package com.giovanna.bibliotecabackend.dto;

import com.giovanna.bibliotecabackend.model.Usuario;
import lombok.Data;

@Data
public class UsuarioBuscaDTO {
    private Long id;
    private String nome;
    private String bio;
    private String fotoPerfil;
    private long totalLivros;
    private long totalAvaliacoes;
    private Double mediaAvaliacoes;
    private long totalSeguidores;
    private boolean estouSeguindo;
    private boolean segueVoce;
    private boolean souEu;

    public static UsuarioBuscaDTO fromEntity(
            Usuario u,
            long totalLivros,
            long totalAvaliacoes,
            Double media,
            long totalSeguidores,
            boolean estouSeguindo,
            boolean segueVoce,
            boolean souEu
    ) {
        UsuarioBuscaDTO dto = new UsuarioBuscaDTO();
        dto.setId(u.getId());
        dto.setNome(u.getNome());
        dto.setBio(u.getBio());
        dto.setFotoPerfil(u.getFotoPerfil());
        dto.setTotalLivros(totalLivros);
        dto.setTotalAvaliacoes(totalAvaliacoes);
        dto.setMediaAvaliacoes(media == null ? null : Math.round(media * 10.0) / 10.0);
        dto.setTotalSeguidores(totalSeguidores);
        dto.setEstouSeguindo(estouSeguindo);
        dto.setSegueVoce(segueVoce);
        dto.setSouEu(souEu);
        return dto;
    }
}
