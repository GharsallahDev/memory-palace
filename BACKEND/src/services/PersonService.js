// src/services/PersonService.js
const Person = require('../models/Person');
const dbService = require('./DatabaseService');
const PatientService = require('./PatientService');
const { getLocalIP } = require('../utils/helpers');

class PersonService {
  constructor() {
    this.db = dbService.getDb();
    this.patientService = new PatientService();
  }

  _enrichPerson(personRow) {
    if (!personRow) return null;

    const person = Person.fromDB(personRow);

    if (person.avatar_file) {
      const ip = getLocalIP();
      const port = process.env.PORT || 3000;
      person.avatarUrl = `http://${ip}:${port}/uploads/${person.avatar_file}`;
    } else {
      person.avatarUrl = null;
    }

    return person.toJSON();
  }

  createPerson(personData) {
    const person = new Person(personData);
    const insertData = person.toDBInsert();

    try {
      const stmt = this.db.prepare(`
        INSERT INTO people (name, relationship, created_at, last_seen_at, device_name)
        VALUES (@name, @relationship, @created_at, @last_seen_at, @device_name)
      `);
      const result = stmt.run(insertData);
      person.id = result.lastInsertRowid;
      return person;
    } catch (error) {
      if (error.code === 'SQLITE_CONSTRAINT_UNIQUE') {
        throw new Error(`Person with name '${person.name}' already exists.`);
      }
      console.error('❌ DB Error creating person:', error.message);
      throw error;
    }
  }

  updatePerson(id, updates) {
    const person = this.findById(id);
    if (!person) {
      throw new Error(`Person with ID ${id} not found.`);
    }

    if (updates.name) person.name = updates.name;
    if (updates.relationship !== undefined) person.relationship = updates.relationship;

    const stmt = this.db.prepare(`
      UPDATE people SET name = ?, relationship = ? WHERE id = ?
    `);
    stmt.run(person.name, person.relationship, id);
    return person;
  }

  findById(id) {
    const stmt = this.db.prepare('SELECT * FROM people WHERE id = ?');
    const row = stmt.get(id);
    return row ? Person.fromDB(row) : null;
  }

  findByName(name) {
    const stmt = this.db.prepare('SELECT * FROM people WHERE LOWER(name) = LOWER(?)');
    const row = stmt.get(name);
    return row ? Person.fromDB(row) : null;
  }

  async getAllPeople() {
    const stmt = this.db.prepare('SELECT * FROM people ORDER BY name ASC');
    const peopleRows = stmt.all();
    const allPeople = peopleRows.map((row) => this._enrichPerson(row));

    const patientProfile = await this.patientService.getCurrentProfile();

    if (patientProfile) {
      const ip = getLocalIP();
      const port = process.env.PORT || 3000;
      let avatarUrl = null;
      if (patientProfile.photoFile) {
        avatarUrl = `http://${ip}:${port}/uploads/${patientProfile.photoFile}`;
      }

      const primaryPerson = {
        id: -1,
        name: patientProfile.name,
        relationship: 'Primary Profile',
        createdAt: patientProfile.createdAt,
        lastSeenAt: new Date().toISOString(),
        avatarUrl: avatarUrl,
        isPrimary: true,
      };

      allPeople.unshift(primaryPerson);
    }

    return allPeople;
  }

  deletePerson(id) {
    const stmt = this.db.prepare('DELETE FROM people WHERE id = ?');
    const result = stmt.run(id);
    if (result.changes === 0) {
      throw new Error(`Person with ID ${id} not found.`);
    }
    return true;
  }

  getStats() {
    const stmt = this.db.prepare(`
      SELECT COUNT(id) as totalPeople
      FROM people
    `);
    const stats = stmt.get();
    return {
      totalPeople: stats.totalPeople || 0,
    };
  }
}

module.exports = PersonService;