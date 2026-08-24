package com.giovanna.bibliotecabackend.repository;

import com.giovanna.bibliotecabackend.model.Avaliacao;
import com.giovanna.bibliotecabackend.model.Curtida;
import com.giovanna.bibliotecabackend.model.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface CurtidaRepository extends JpaRepository<Curtida, Long> {

    Optional<Curtida> findByAvaliacaoAndUsuario(Avaliacao avaliacao, Usuario usuario);

    boolean existsByAvaliacaoAndUsuario(Avaliacao avaliacao, Usuario usuario);

    long countByAvaliacao(Avaliacao avaliacao);

    @Query("SELECT COUNT(c) FROM Curtida c WHERE c.avaliacao = :a")
    long countPorAvaliacao(@Param("a") Avaliacao avaliacao);

    @Query("SELECT COUNT(c) FROM Curtida c WHERE c.avaliacao.id IN :ids")
    long countPorIdsAvaliacao(@Param("ids") Collection<Long> idsAvaliacoes);

    @Query("SELECT c.avaliacao.id, COUNT(c) FROM Curtida c WHERE c.avaliacao.id IN :ids GROUP BY c.avaliacao.id")
    List<Object[]> countsPorIdsAvaliacaoAgrupado(@Param("ids") Collection<Long> idsAvaliacoes);

    @Query("SELECT c.avaliacao.id FROM Curtida c WHERE c.usuario = :u AND c.avaliacao.id IN :ids")
    List<Long> idsDasAvaliacoesQueEuCurti(@Param("u") Usuario usuario, @Param("ids") Collection<Long> idsAvaliacoes);

    @Modifying
    @Transactional
    @Query("DELETE FROM Curtida c WHERE c.avaliacao = :a AND c.usuario = :u")
    void deleteByAvaliacaoAndUsuario(@Param("a") Avaliacao avaliacao, @Param("u") Usuario usuario);
}
