/*
 * Copyright (C) 2015 Southern Storm Software, Pty Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#include "AES.h"
#include "Crypto.h"
#include <string.h>

/**
 * \class AES128 AES.h <AES.h>
 * \brief AES block cipher with 128-bit keys.
 *
 * \sa AES192, AES256
 */

/**
 * \brief Constructs an AES 128-bit block cipher with no initial key.
 *
 * This constructor must be followed by a call to setKey() before the
 * block cipher can be used for encryption or decryption.
 */
AES128::AES128()
{
    rounds = 10;
    schedule = sched;
}

AES128::~AES128()
{
    clean(sched);
}

/**
 * \brief Size of a 128-bit AES key in bytes.
 * \return Always returns 16.
 */
size_t AES128::keySize() const
{
    return 16;
}

bool AES128::setKey(const uint8_t *key, size_t len)
{
    if (len != 16)
        return false;

    // Copy the key itself into the first 16 bytes of the schedule.
    uint8_t *schedule = sched;
    memcpy(schedule, key, 16);

    // Expand the key schedule until we have 176 bytes of expanded key.
    uint8_t iteration = 1;
    uint8_t n = 16;
    uint8_t w = 4;
    while (n < 176) {
        if (w == 4) {
            // Every 16 bytes (4 words) we need to apply the key schedule core.
            keyScheduleCore(schedule + 16, schedule + 12, iteration);
            schedule[16] ^= schedule[0];
            schedule[17] ^= schedule[1];
            schedule[18] ^= schedule[2];
            schedule[19] ^= schedule[3];
            ++iteration;
            w = 0;
        } else {
            // Otherwise just XOR the word with the one 16 bytes previous.
            schedule[16] = schedule[12] ^ schedule[0];
            schedule[17] = schedule[13] ^ schedule[1];
            schedule[18] = schedule[14] ^ schedule[2];
            schedule[19] = schedule[15] ^ schedule[3];
        }

        // Advance to the next word in the schedule.
        schedule += 4;
        n += 4;
        ++w;
    }

    return true;
}
