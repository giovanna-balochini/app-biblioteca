package com.giovanna.bibliotecabackend.repository;

import com.giovanna.bibliotecabackend.model.Livro;
import com.giovanna.bibliotecabackend.model.StatusLeitura;
import com.giovanna.bibliotecabackend.model.Usuario;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface LivroRepository extends JpaRepository<Livro, Long> {
    List<Livro> findByDono(Usuario dono);

    List<Livro> findByDonoAndStatusLeitura(Usuario dono, StatusLeitura statusLeitura);

    long countByDono(Usuario dono);

    long countByDonoAndStatusLeitura(Usuario dono, StatusLeitura statusLeitura);

    @Query("SELECT l FROM Livro l WHERE " +
           "LOWER(l.titulo) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(l.autor) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(l.genero) LIKE LOWER(CONCAT('%', :q, '%'))")
    Page<Livro> buscarPorTituloAutorGenero(@Param("q") String q, Pageable pageable);

    @Query("SELECT COUNT(l) > 0 FROM Livro l WHERE l.dono = :eu AND LOWER(l.titulo) = LOWER(:titulo) AND LOWER(l.autor) = LOWER(:autor)")
    boolean existeNaBibliotecaDe(@Param("eu") Usuario eu, @Param("titulo") String titulo, @Param("autor") String autor);

    @Query("SELECT SUM(CASE WHEN l.totalPaginas IS NOT NULL AND l.paginaAtual IS NOT NULL AND l.totalPaginas > 0 THEN l.paginaAtual ELSE 0 END) FROM Livro l WHERE l.dono = :dono AND l.statusLeitura = com.giovanna.bibliotecabackend.model.StatusLeitura.LENDO")
    Long somarPaginasLidasAtualmente(@Param("dono") Usuario dono);

    @Query("SELECT SUM(CASE WHEN l.totalPaginas IS NOT NULL AND l.totalPaginas > 0 THEN l.totalPaginas ELSE 0 END) FROM Livro l WHERE l.dono = :dono AND l.statusLeitura = com.giovanna.bibliotecabackend.model.StatusLeitura.LENDO")
    Long somarTotalPaginasAtualmente(@Param("dono") Usuario dono);
}
