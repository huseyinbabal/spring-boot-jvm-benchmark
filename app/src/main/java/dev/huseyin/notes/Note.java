package dev.huseyin.notes;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "notes")
public class Note {
	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	private Long id;
	private String title;
	private String body;
	private String tag;
	private Instant createdAt = Instant.now();

	protected Note() {}

	public Note(String title, String body, String tag) {
		this.title = title;
		this.body = body;
		this.tag = tag;
	}

	public Long getId() { return id; }
	public String getTitle() { return title; }
	public String getBody() { return body; }
	public String getTag() { return tag; }
	public Instant getCreatedAt() { return createdAt; }
	public void setTitle(String title) { this.title = title; }
	public void setBody(String body) { this.body = body; }
	public void setTag(String tag) { this.tag = tag; }
}
