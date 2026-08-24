package com.giovanna.bibliotecabackend.repository;

import com.giovanna.bibliotecabackend.model.Avaliacao;
import com.giovanna.bibliotecabackend.model.Livro;
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
public interface AvaliacaoRepository extends JpaRepository<Avaliacao, Long> {

    @Query("SELECT a FROM Avaliacao a JOIN FETCH a.autor WHERE a.livro = :livro ORDER BY a.dataCriacao DESC")
    List<Avaliacao> findByLivroComAutor(Livro livro);

    Optional<Avaliacao> findByAutorAndLivro(Usuario autor, Livro livro);

    boolean existsByAutorAndLivro(Usuario autor, Livro livro);

    @Query("SELECT AVG(a.nota) FROM Avaliacao a WHERE a.livro = :livro")
    Double calcularMediaPorLivro(Livro livro);

    @Query(value = "SELECT a FROM Avaliacao a JOIN FETCH a.autor JOIN FETCH a.livro ORDER BY a.dataCriacao DESC",
           countQuery = "SELECT COUNT(a) FROM Avaliacao a")
    Page<Avaliacao> findFeedPaginado(Pageable pageable);

    @Query(value = "SELECT a FROM Avaliacao a JOIN FETCH a.autor JOIN FETCH a.livro WHERE a.autor.id IN :idsAutores ORDER BY a.dataCriacao DESC",
           countQuery = "SELECT COUNT(a) FROM Avaliacao a WHERE a.autor.id IN :idsAutores")
    Page<Avaliacao> findFeedPaginadoDeAutores(@Param("idsAutores") List<Long> idsAutores, Pageable pageable);

    long countByAutor(Usuario autor);

    long countByLivro(Livro livro);

    @Query("SELECT AVG(a.nota) FROM Avaliacao a WHERE a.autor = :autor")
    Double calcularMediaPorAutor(Usuario autor);

    @Query(value = "SELECT a FROM Avaliacao a JOIN FETCH a.livro WHERE a.autor = :autor ORDER BY a.dataCriacao DESC",
           countQuery = "SELECT COUNT(a) FROM Avaliacao a WHERE a.autor = :autor")
    Page<Avaliacao> findByAutorPaginado(Usuario autor, Pageable pageable);
}
