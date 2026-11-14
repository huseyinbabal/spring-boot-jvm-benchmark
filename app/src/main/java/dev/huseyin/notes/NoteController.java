package dev.huseyin.notes;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/notes")
public class NoteController {
	record NoteRequest(@NotBlank String title, @NotBlank String body, @NotBlank String tag) {}

	private final NoteRepository notes;

	NoteController(NoteRepository notes) {
		this.notes = notes;
	}

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	Note create(@Valid @RequestBody NoteRequest r) {
		return notes.save(new Note(r.title(), r.body(), r.tag()));
	}

	@GetMapping("/{id}")
	ResponseEntity<Note> get(@PathVariable long id) {
		return ResponseEntity.of(notes.findById(id));
	}

	@GetMapping
	List<Note> byTag(@RequestParam String tag) {
		return notes.findByTagOrderByIdDesc(tag, PageRequest.of(0, 20));
	}

	@GetMapping("/search")
	List<Note> search(@RequestParam String q) {
		return notes.findByTitleContainingIgnoreCase(q, PageRequest.of(0, 20));
	}

	@PutMapping("/{id}")
	@Transactional
	ResponseEntity<Note> update(@PathVariable long id, @Valid @RequestBody NoteRequest r) {
		return notes.findById(id).map(n -> {
			n.setTitle(r.title());
			n.setBody(r.body());
			n.setTag(r.tag());
			return ResponseEntity.ok(n);
		}).orElse(ResponseEntity.notFound().build());
	}

	@DeleteMapping("/{id}")
	ResponseEntity<Void> delete(@PathVariable long id) {
		if (!notes.existsById(id)) return ResponseEntity.notFound().build();
		notes.deleteById(id);
		return ResponseEntity.noContent().build();
	}
}
