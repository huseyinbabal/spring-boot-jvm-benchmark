package dev.huseyin.notes;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface NoteRepository extends JpaRepository<Note, Long> {
	List<Note> findByTagOrderByIdDesc(String tag, Pageable page);
	List<Note> findByTitleContainingIgnoreCase(String q, Pageable page);
}
