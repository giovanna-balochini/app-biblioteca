package com.giovanna.bibliotecabackend.repository;

import com.giovanna.bibliotecabackend.model.Seguidor;
import com.giovanna.bibliotecabackend.model.Usuario;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SeguidorRepository extends JpaRepository<Seguidor, Long> {

    Optional<Seguidor> findBySeguidorAndSeguido(Usuario seguidor, Usuario seguido);

    boolean existsBySeguidorAndSeguido(Usuario seguidor, Usuario seguido);

    long countBySeguido(Usuario seguido);

    long countBySeguidor(Usuario seguidor);

    void deleteBySeguidorAndSeguido(Usuario seguidor, Usuario seguido);

    @Query("SELECT s.seguido.id FROM Seguidor s WHERE s.seguidor = :seguidor")
    List<Long> findIdsSeguidosPor(Usuario seguidor);

    @Query(value = "SELECT s.seguidor FROM Seguidor s WHERE s.seguido = :alvo ORDER BY s.dataCriacao DESC",
           countQuery = "SELECT COUNT(s) FROM Seguidor s WHERE s.seguido = :alvo")
    Page<Usuario> findSeguidoresDe(@Param("alvo") Usuario alvo, Pageable pageable);

    @Query(value = "SELECT s.seguido FROM Seguidor s WHERE s.seguidor = :alvo ORDER BY s.dataCriacao DESC",
           countQuery = "SELECT COUNT(s) FROM Seguidor s WHERE s.seguidor = :alvo")
    Page<Usuario> findSeguindoDe(@Param("alvo") Usuario alvo, Pageable pageable);
}
