import test from 'node:test'
import assert from 'node:assert/strict'
import { parseProfileSex } from '../supabase/functions/username-signup/profile.ts'

test('signup rejects missing or unsupported sex values', () => {
  for (const value of [undefined, null, '', false, 0, 'later', 'MALE', [], {}, ' male ']) {
    assert.equal(parseProfileSex(value), null)
  }
})

test('signup accepts only explicit male or female selection', () => {
  assert.equal(parseProfileSex('male'), 'male')
  assert.equal(parseProfileSex('female'), 'female')
})
