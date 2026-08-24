package com.giovanna.bibliotecabackend.repository;

import com.giovanna.bibliotecabackend.model.PreferenciaLembrete;
import com.giovanna.bibliotecabackend.model.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface PreferenciaLembreteRepository extends JpaRepository<PreferenciaLembrete, Long> {
    Optional<PreferenciaLembrete> findByUsuario(Usuario usuario);
}
