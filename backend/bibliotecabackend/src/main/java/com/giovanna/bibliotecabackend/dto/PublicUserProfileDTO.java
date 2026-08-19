package com.giovanna.bibliotecabackend.dto;

import com.giovanna.bibliotecabackend.model.Usuario;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class PublicUserProfileDTO {
    private Long id;
    private String nome;
    private String bio;
    private String fotoPerfil;
    private LocalDateTime dataCriacao;

    private long totalLivros;
    private long totalAvaliacoes;
    private Double mediaAvaliacoes;

    private long totalSeguidores;
    private long totalSeguindo;
    private boolean estouSeguindo;
    private boolean segueVoce;
    private boolean souEu;

    public static PublicUserProfileDTO fromEntity(
            Usuario u,
            long totalLivros,
            long totalAvaliacoes,
            Double mediaAvaliacoes,
            long totalSeguidores,
            long totalSeguindo,
            boolean estouSeguindo,
            boolean segueVoce,
            Long idUsuarioLogado
    ) {
        PublicUserProfileDTO dto = new PublicUserProfileDTO();
        dto.setId(u.getId());
        dto.setNome(u.getNome());
        dto.setBio(u.getBio());
        dto.setFotoPerfil(u.getFotoPerfil());
        dto.setDataCriacao(u.getDataCriacao());
        dto.setTotalLivros(totalLivros);
        dto.setTotalAvaliacoes(totalAvaliacoes);
        dto.setMediaAvaliacoes(mediaAvaliacoes == null ? null : Math.round(mediaAvaliacoes * 10.0) / 10.0);
        dto.setTotalSeguidores(totalSeguidores);
        dto.setTotalSeguindo(totalSeguindo);
        dto.setEstouSeguindo(estouSeguindo);
        dto.setSegueVoce(segueVoce);
        dto.setSouEu(idUsuarioLogado != null && u.getId() != null && u.getId().equals(idUsuarioLogado));
        return dto;
    }

    public static PublicUserProfileDTO fromUsuarioResumido(
            Usuario u,
            boolean estouSeguindo,
            boolean segueVoce,
            boolean souEu,
            long totalSeguidores,
            long totalSeguindo
    ) {
        PublicUserProfileDTO dto = new PublicUserProfileDTO();
        dto.setId(u.getId());
        dto.setNome(u.getNome());
        dto.setBio(u.getBio());
        dto.setFotoPerfil(u.getFotoPerfil());
        dto.setDataCriacao(u.getDataCriacao());
        dto.setTotalLivros(0);
        dto.setTotalAvaliacoes(0);
        dto.setMediaAvaliacoes(null);
        dto.setTotalSeguidores(totalSeguidores);
        dto.setTotalSeguindo(totalSeguindo);
        dto.setEstouSeguindo(estouSeguindo);
        dto.setSegueVoce(segueVoce);
        dto.setSouEu(souEu);
        return dto;
    }
}
