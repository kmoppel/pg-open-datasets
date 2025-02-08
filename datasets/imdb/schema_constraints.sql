ALTER TABLE name_basics ADD PRIMARY KEY (nconst);

ALTER TABLE title_akas ADD PRIMARY KEY (title_id, ordering);

ALTER TABLE title_basics ADD PRIMARY KEY (tconst);

ALTER TABLE title_crew ADD PRIMARY KEY (tconst);

ALTER TABLE title_episode ADD PRIMARY KEY (tconst);

ALTER TABLE title_principals ADD PRIMARY KEY (tconst, ordering);

ALTER TABLE title_ratings ADD PRIMARY KEY (tconst);
