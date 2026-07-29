package com.giovanna.bibliotecabackend.repository;

import com.giovanna.bibliotecabackend.model.Livro;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface LivroRepository extends JpaRepository<Livro, Long> {
    
}