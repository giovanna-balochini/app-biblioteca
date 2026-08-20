package com.giovanna.bibliotecabackend.repository;

import com.giovanna.bibliotecabackend.model.Notificacao;
import com.giovanna.bibliotecabackend.model.Usuario;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface NotificacaoRepository extends JpaRepository<Notificacao, Long> {

    Page<Notificacao> findByUsuarioOrderByDataCriacaoDesc(Usuario usuario, Pageable pageable);

    long countByUsuarioAndLidaFalse(Usuario usuario);

    @Modifying
    @Query("UPDATE Notificacao n SET n.lida = true WHERE n.usuario = :usuario AND n.lida = false")
    int marcarTodasComoLidas(@Param("usuario") Usuario usuario);

    boolean existsByIdAndUsuario(Long id, Usuario usuario);

    long deleteByUsuario(Usuario usuario);
}
